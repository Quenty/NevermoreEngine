"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[59173],{23364:e=>{e.exports=JSON.parse('{"functions":[{"name":"newSplineNode","desc":"Creates a new spline node.","params":[{"name":"t","desc":"","lua_type":"number"},{"name":"position","desc":"","lua_type":"T"},{"name":"velocity","desc":"","lua_type":"T"}],"returns":[{"desc":"","lua_type":"CubicSplineNode<T>"}],"function_type":"static","source":{"line":30,"path":"src/cubicspline/src/Shared/CubicSplineUtils.lua"}},{"name":"tween","desc":"Interpolates between the nodes at a given point.","params":[{"name":"nodeList","desc":"Should be sorted.","lua_type":"{ CubicSplineNode<T> }"},{"name":"t","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"CubicSplineNode<T>"}],"function_type":"static","source":{"line":44,"path":"src/cubicspline/src/Shared/CubicSplineUtils.lua"}},{"name":"cloneSplineNode","desc":"Clones a cubic spline.","params":[{"name":"node","desc":"","lua_type":"CubicSplineNode<T>"}],"returns":[{"desc":"","lua_type":"CubicSplineNode<T>"}],"function_type":"static","source":{"line":67,"path":"src/cubicspline/src/Shared/CubicSplineUtils.lua"}},{"name":"tweenSplineNodes","desc":"Interpolates between 2 cubic spline nodes.","params":[{"name":"node0","desc":"","lua_type":"CubicSplineNode<T>"},{"name":"node1","desc":"","lua_type":"CubicSplineNode<T>"},{"name":"t","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"CubicSplineNode<T>"}],"function_type":"static","source":{"line":78,"path":"src/cubicspline/src/Shared/CubicSplineUtils.lua"}},{"name":"sort","desc":"Sorts a cubic spline nodme based upon the time stamp","params":[{"name":"nodeList","desc":"","lua_type":"{ CubicSplineNode<T> }"}],"returns":[],"function_type":"static","source":{"line":96,"path":"src/cubicspline/src/Shared/CubicSplineUtils.lua"}},{"name":"populateVelocities","desc":"For a given node list, populates the velocity values of the nodes.","params":[{"name":"nodeList","desc":"","lua_type":"{ CubicSplineNode<T> }"},{"name":"i0","desc":"","lua_type":"number?"},{"name":"i1","desc":"","lua_type":"number?"}],"returns":[],"function_type":"static","source":{"line":117,"path":"src/cubicspline/src/Shared/CubicSplineUtils.lua"}}],"properties":[],"types":[{"name":"CubicSplineNode","desc":"A node that can be used as part of a cubic spline.","fields":[{"name":"t","lua_type":"number","desc":""},{"name":"p","lua_type":"T","desc":""},{"name":"v","lua_type":"T","desc":""}],"source":{"line":22,"path":"src/cubicspline/src/Shared/CubicSplineUtils.lua"}}],"name":"CubicSplineUtils","desc":"Utility methods involving cubic splines.","source":{"line":5,"path":"src/cubicspline/src/Shared/CubicSplineUtils.lua"}}')}}]);