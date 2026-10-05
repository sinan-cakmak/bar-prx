"""Exercise the exact embedded addon supplied on stdin, without mitmproxy installed."""
import asyncio
import json
import pathlib
import sys
import tempfile
import types
import unittest
from unittest.mock import AsyncMock, patch


class Response:
    def __init__(self, status_code, content, headers):
        self.status_code = status_code
        self.content = content
        self.headers = headers
        self.stream = False

    @classmethod
    def make(cls, *args):
        return cls(*args)


sys.modules["mitmproxy"] = types.SimpleNamespace(
    http=types.SimpleNamespace(HTTPFlow=object, Response=Response)
)
addon = types.ModuleType("response_override")
exec(compile(sys.stdin.read(), "response_override.py", "exec"), addon.__dict__)


def flow(path="/users", method="GET"):
    return types.SimpleNamespace(
        request=types.SimpleNamespace(
            pretty_url="https://example.test" + path, method=method,
            headers={"Origin": "https://client.test"},
        ),
        response=None, metadata={},
    )


def rule(**fields):
    return dict(endpoint="/users", enabled=True, statusCode=201,
                responseBody='{"mock":true}', **fields)


class AddonTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        addon.OVERRIDES_PATH = str(pathlib.Path(self.temp.name) / "overrides.json")
        self.configure([])

    def configure(self, rules, cors=False):
        pathlib.Path(addon.OVERRIDES_PATH).write_text(
            json.dumps({"rules": rules, "corsBypass": cors})
        )
        addon._cache["mtime"] = None

    async def respond(self, current):
        with patch.object(addon.asyncio, "sleep", new_callable=AsyncMock) as sleep:
            await addon.response(current)
        return sleep

    async def test_delay_only_preserves_upstream_response(self):
        self.configure([rule(overrideResponse=False, delaySeconds=5)])
        current = flow()
        addon.request(current)
        self.assertIsNone(current.response)
        upstream = Response(202, b"original", {"X-Upstream": "yes"})
        upstream.stream = True
        current.response = upstream
        with patch.object(addon.asyncio, "sleep", new_callable=AsyncMock) as sleep:
            await addon.responseheaders(current)
        sleep.assert_awaited_once_with(5)
        self.assertTrue(upstream.stream)
        (await self.respond(current)).assert_not_awaited()
        self.assertIs(current.response, upstream)
        self.assertEqual(upstream.content, b"original")
        self.assertEqual(upstream.status_code, 202)
        self.assertEqual(upstream.headers, {"X-Upstream": "yes"})
        (await self.respond(current)).assert_not_awaited()

    async def test_delayed_mock(self):
        self.configure([rule(delaySeconds=0.5)])
        current = flow()
        addon.request(current)
        self.assertEqual(current.response.status_code, 201)
        self.assertEqual(current.response.content, b'{"mock":true}')
        self.assertEqual(current.response.headers["Access-Control-Allow-Origin"],
                         "https://client.test")
        (await self.respond(current)).assert_awaited_once_with(0.5)

    async def test_legacy_mock_has_no_delay(self):
        self.configure([rule()])
        current = flow()
        addon.request(current)
        self.assertEqual(current.response.status_code, 201)
        (await self.respond(current)).assert_not_awaited()

    async def test_unmatched_disabled_empty_and_method_filtered_rules(self):
        cases = [dict(endpoint="/other"), dict(enabled=False), dict(endpoint=""),
                 dict(method="POST")]
        for fields in cases:
            configured = rule(delaySeconds=5)
            configured.update(fields)
            self.configure([configured])
            current = flow()
            addon.request(current)
            self.assertIsNone(current.response)
            self.assertEqual(current.metadata, {})
            (await self.respond(current)).assert_not_awaited()

    async def test_invalid_and_zero_delays_do_not_wait(self):
        for delay in [0, -5, None, "bad", "NaN", "Infinity", "-Infinity"]:
            self.configure([rule(delaySeconds=delay)])
            current = flow()
            addon.request(current)
            (await self.respond(current)).assert_not_awaited()

    async def test_first_matching_rule_wins_and_edits_do_not_change_inflight_delay(self):
        self.configure([rule(overrideResponse=False, delaySeconds=5), rule(delaySeconds=10)])
        current = flow()
        addon.request(current)
        self.assertIsNone(current.response)
        self.configure([rule(delaySeconds=10)])
        (await self.respond(current)).assert_awaited_once_with(5)
        next_flow = flow()
        addon.request(next_flow)
        (await self.respond(next_flow)).assert_awaited_once_with(10)

    async def test_delay_only_preflight_passes_through(self):
        self.configure([rule(overrideResponse=False, delaySeconds=5, method="GET")])
        current = flow(method="OPTIONS")
        addon.request(current)
        self.assertIsNone(current.response)
        (await self.respond(current)).assert_not_awaited()

    async def test_mock_and_global_cors_preflights_have_no_delay(self):
        for override, cors in [(True, False), (False, True)]:
            self.configure([rule(overrideResponse=override, delaySeconds=5, method="GET")], cors)
            current = flow(method="OPTIONS")
            addon.request(current)
            self.assertEqual(current.response.status_code, 204)
            (await self.respond(current)).assert_not_awaited()

    async def test_global_cors_still_applies_with_delay(self):
        self.configure([rule(overrideResponse=False, delaySeconds=5)], cors=True)
        current = flow()
        addon.request(current)
        current.response = Response(200, b"real", {})
        (await self.respond(current)).assert_awaited_once_with(5)
        self.assertEqual(current.response.headers["Access-Control-Allow-Origin"],
                         "https://client.test")

    async def test_unrelated_response_completes_during_delay(self):
        self.configure([rule(overrideResponse=False, delaySeconds=0.1)])
        delayed, unrelated = flow(), flow("/other")
        addon.request(delayed)
        addon.request(unrelated)
        delayed_task = asyncio.create_task(addon.response(delayed))
        await asyncio.sleep(0)
        await addon.response(unrelated)
        self.assertFalse(delayed_task.done())
        await delayed_task


if __name__ == "__main__":
    unittest.main()
