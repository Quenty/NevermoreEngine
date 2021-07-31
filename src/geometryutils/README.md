## GeometryUtils
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Utility functions involving 3D and 2D geometry

## Installation
```
npm install @quenty/geometryutils --save
```

## Usage
Usage is designed to be simple.

## SwingTwistUTils

### `SwingTwistUtils.swingTwist(cf, direction)`

### `SwingTwistUtils.twistAngle(cf, direction)`

## SurfaceUtils API

### `SurfaceUtils.getSurfaceCFrame(part, lnormal)`

## PlaneUtils API

### `PlaneUtils.rayIntersection(origin, normal, rayOrigin, unitRayDirection)`

## SphereUtils API

### `SphereUtils.intersectsRay(sphereCenter, sphereRadius, rayOrigin, rayDirection)`

## CircleUtils API

### `CircleUtils.updatePositionToSmallestDistOnCircle(position, target, circumference)`

## OrthogonalUtils API

### `OrthogonalUtils.decomposeCFrameToVectors(cframe)`

### `OrthogonalUtils.getClosestVector(options, unitVector)`

### `OrthogonalUtils.snapCFrameTo(cframe, snapToCFrame)`

## CFrameMirror API
API surface to mirror CFrames

### `CFrameMirror.new()`

### `CFrameMirror:SetCFrame(reflectOver)`

### `CFrameMirror:Reflect(cframe)`

### `CFrameMirror:ReflectVector(vector)`

### `CFrameMirror:ReflectPoint(point)`

### `CFrameMirror:ReflectRay(ray)`

## Line API

### `Line.Intersect(a, r, b, s)`
