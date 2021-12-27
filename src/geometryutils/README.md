## GeometryUtils
<div align="center">
  <a href="http://quenty.github.io/NevermoreEngine/">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Utility functions involving 3D and 2D geometry

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/PlaneUtils">View docs →</a></div>

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
