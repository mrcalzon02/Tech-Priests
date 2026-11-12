"""Dependency-free tests; run without Blender or source archive."""
import unittest
from condenser_v22_timing import CYCLE, FPS, HEADS, PREVIEW_FRAMES, STROKE, head_lift, inward_stream, signals, slot_phase, snake_order


class MotionScheduleTest(unittest.TestCase):
    def test_cycle_is_twelve_seconds_and_closes(self):
        self.assertEqual((CYCLE, FPS, CYCLE // FPS), (96, 8, 12))
        for head in range(HEADS):
            self.assertEqual(head_lift(1, head), head_lift(97, head))
            self.assertEqual(inward_stream(1, head), inward_stream(97, head))
        self.assertEqual(signals(1), signals(97))

    def test_one_head_at_a_time_and_no_idle_motion(self):
        for frame in range(1, 98):
            raised = [i for i in range(HEADS) if head_lift(frame, i) > 1e-8]
            self.assertLessEqual(len(raised), 1)
            if raised:
                self.assertEqual(raised[0], slot_phase(frame)[0])
            for head in range(HEADS):
                self.assertGreaterEqual(head_lift(frame, head), 0)
                self.assertLessEqual(head_lift(frame, head), STROKE)

    def test_each_head_lifts_and_each_stream_moves_inward(self):
        self.assertEqual(len(PREVIEW_FRAMES), 32)
        for head in range(HEADS):
            start = 1 + head * 12
            self.assertEqual(head_lift(start, head), 0)
            self.assertAlmostEqual(head_lift(start + 6, head), STROKE)
            lo, hi = inward_stream(start + 6, head)
            self.assertGreater(hi, lo)
            self.assertGreater(hi, 0)
            self.assertEqual(inward_stream(start + 6, (head + 1) % HEADS), (0, 0))

    def test_visual_left_right_return_order(self):
        coords = [(f'canister_{j}', float(j % 4), float(j // 4)) for j in range(8)]
        self.assertEqual(snake_order(coords), ['canister_0','canister_1','canister_2','canister_3','canister_7','canister_6','canister_5','canister_4'])
        with self.assertRaises(ValueError):
            snake_order(coords[:7])

    def test_lamps_are_bounded(self):
        for frame in range(1, 98):
            for value in signals(frame).values():
                self.assertLessEqual(value, 1.0)
                self.assertGreaterEqual(value, 0)


if __name__ == '__main__':
    unittest.main()
