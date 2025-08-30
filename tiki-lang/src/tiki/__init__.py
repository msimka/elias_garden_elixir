"""
Tiki Hierarchical Specification Language

A revolutionary spec-first programming approach using hierarchical documentation trees.
"""

__version__ = "0.1.0"

from .core import TikiNode
from .parser import TikiParser
from .renderer import TikiRenderer
from .navigator import TikiNavigator

__all__ = ["TikiNode", "TikiParser", "TikiRenderer", "TikiNavigator"]