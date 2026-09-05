"""
geometry.py
Mathematical model for Dynamic Island geometry and inverted corner fillets ('ears').
Verifies Bézier curves, G1/tangent continuity, flush bezel alignment, and symmetry.
"""

import math
from typing import List, Tuple, Dict, Any

# Standard kappa constant for cubic Bézier circle approximation
KAPPA = 0.5522847498307935

class Point:
    def __init__(self, x: float, y: float):
        self.x = float(x)
        self.y = float(y)

    def __repr__(self):
        return f"Point({self.x:.3f}, {self.y:.3f})"

    def distance_to(self, other: 'Point') -> float:
        return math.hypot(self.x - other.x, self.y - other.y)

class CubicBezier:
    def __init__(self, p0: Point, p1: Point, p2: Point, p3: Point):
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3

    def point_at(self, t: float) -> Point:
        """Evaluate B(t) for t in [0, 1]."""
        u = 1.0 - t
        x = (u**3 * self.p0.x +
             3 * u**2 * t * self.p1.x +
             3 * u * t**2 * self.p2.x +
             t**3 * self.p3.x)
        y = (u**3 * self.p0.y +
             3 * u**2 * t * self.p1.y +
             3 * u * t**2 * self.p2.y +
             t**3 * self.p3.y)
        return Point(x, y)

    def derivative_at(self, t: float) -> Tuple[float, float]:
        """Evaluate B'(t) = (dx/dt, dy/dt)."""
        u = 1.0 - t
        dx = (3 * u**2 * (self.p1.x - self.p0.x) +
              6 * u * t * (self.p2.x - self.p1.x) +
              3 * t**2 * (self.p3.x - self.p2.x))
        dy = (3 * u**2 * (self.p1.y - self.p0.y) +
              6 * u * t * (self.p2.y - self.p1.y) +
              3 * t**2 * (self.p3.y - self.p2.y))
        return (dx, dy)

    def tangent_slope_at(self, t: float) -> float:
        """Evaluate dy/dx at t. Returns float('inf') if dx is zero."""
        dx, dy = self.derivative_at(t)
        if abs(dx) < 1e-9:
            return float('inf') if dy >= 0 else float('-inf')
        return dy / dx


class IslandEarGeometry:
    """
    Computes the inverted corner fillet ('ear') for the top screen bezel.
    The top bezel is at Y = 0.
    Island body top edge is flush with Y = 0.
    """
    @staticmethod
    def construct_left_ear(island_x: float, radius: float) -> CubicBezier:
        """
        Left ear: starts on top bezel at (island_x - radius, 0),
        curves down and inward to meet island body at (island_x, radius).
        """
        p0 = Point(island_x - radius, 0.0)
        # Control 1 is horizontal from p0: (p0.x + radius * KAPPA, 0.0)
        p1 = Point(island_x - radius + radius * (1.0 - KAPPA), 0.0)
        # Control 2 approaches p3 vertically: (island_x, radius * (1.0 - KAPPA))
        p2 = Point(island_x, radius * KAPPA)
        p3 = Point(island_x, radius)
        return CubicBezier(p0, p1, p2, p3)

    @staticmethod
    def construct_right_ear(island_x: float, island_width: float, radius: float) -> CubicBezier:
        """
        Right ear: starts at island body at (island_x + island_width, radius),
        curves up and outward to meet top bezel at (island_x + island_width + radius, 0).
        """
        right_edge = island_x + island_width
        p0 = Point(right_edge, radius)
        p1 = Point(right_edge, radius * KAPPA)
        p2 = Point(right_edge + radius * KAPPA, 0.0)
        p3 = Point(right_edge + radius, 0.0)
        return CubicBezier(p0, p1, p2, p3)

    @staticmethod
    def sample_curve(curve: CubicBezier, steps: int = 50) -> List[Point]:
        return [curve.point_at(i / steps) for i in range(steps + 1)]

    @staticmethod
    def verify_top_bezel_flushness(curve: CubicBezier, side: str) -> bool:
        """Verifies that the attachment point on the screen bezel is strictly Y = 0."""
        if side == "left":
            pt = curve.p0
        else:
            pt = curve.p3
        return abs(pt.y) < 1e-6

    @staticmethod
    def verify_tangent_continuity_at_bezel(curve: CubicBezier, side: str) -> bool:
        """
        Verifies G1 continuity with the top screen bezel:
        The tangent slope dy/dx at the bezel attachment must be 0 (horizontal).
        """
        t = 0.0 if side == "left" else 1.0
        slope = curve.tangent_slope_at(t)
        return abs(slope) < 1e-4

    @staticmethod
    def verify_symmetry(left_curve: CubicBezier, right_curve: CubicBezier, island_center_x: float) -> bool:
        """
        Verifies that right ear is an exact mirror of left ear across the island center axis.
        """
        steps = 50
        for i in range(steps + 1):
            t = i / steps
            pt_left = left_curve.point_at(t)
            # right curve travels from bottom to top, so parameter is inverted
            pt_right = right_curve.point_at(1.0 - t)

            # Check Y matches
            if abs(pt_left.y - pt_right.y) > 1e-4:
                return False

            # Check X distance from center matches
            dist_left = island_center_x - pt_left.x
            dist_right = pt_right.x - island_center_x
            if abs(dist_left - dist_right) > 1e-4:
                return False

        return True
