// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Quad, Vector3, Matrix4;

void main() {
  group('InteractiveViewer', () {
    testWidgets('child fits in viewport', (WidgetTester tester) async {
      final TransformationController transformationController = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveViewer(
                transformationController: transformationController,
                child: Container(width: 200.0, height: 200.0),
              ),
            ),
          ),
        ),
      );

      expect(transformationController.value, equals(Matrix4.identity()));

      // Attempting to drag to pan doesn't work because the child fits inside
      // the viewport and has a tight boundary.
      final Offset childOffset = tester.getTopLeft(find.byType(Container));
      final Offset childInterior = Offset(
        childOffset.dx + 20.0,
        childOffset.dy + 20.0,
      );
      TestGesture gesture = await tester.startGesture(childInterior);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(childOffset);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(transformationController.value, equals(Matrix4.identity()));

      // Pinch to zoom works.
      final Offset scaleStart1 = childInterior;
      final Offset scaleStart2 = Offset(childInterior.dx + 10.0, childInterior.dy);
      final Offset scaleEnd1 = Offset(childInterior.dx - 10.0, childInterior.dy);
      final Offset scaleEnd2 = Offset(childInterior.dx + 20.0, childInterior.dy);
      gesture = await tester.createGesture();
      final TestGesture gesture2 = await tester.createGesture();
      await gesture.down(scaleStart1);
      await gesture2.down(scaleStart2);
      await tester.pump();
      await gesture.moveTo(scaleEnd1);
      await gesture2.moveTo(scaleEnd2);
      await tester.pump();
      await gesture.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(transformationController.value, isNot(equals(Matrix4.identity())));
    });

    testWidgets('boundary slightly bigger than child', (WidgetTester tester) async {
      final TransformationController transformationController = TransformationController();
      const double boundaryMargin = 10.0;
      const double minScale = 0.8;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(boundaryMargin),
                minScale: minScale,
                transformationController: transformationController,
                child: Container(width: 200.0, height: 200.0),
              ),
            ),
          ),
        ),
      );

      expect(transformationController.value, equals(Matrix4.identity()));

      // Dragging to pan works only until it hits the boundary.
      final Offset childOffset = tester.getTopLeft(find.byType(Container));
      final Offset childInterior = Offset(
        childOffset.dx + 20.0,
        childOffset.dy + 20.0,
      );
      TestGesture gesture = await tester.startGesture(childInterior);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(childOffset);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final Vector3 translation = transformationController.value.getTranslation();
      expect(translation.x, -boundaryMargin);
      expect(translation.y, -boundaryMargin);

      // Pinch to zoom also only works until expanding to the boundary.
      final Offset scaleStart1 = childInterior;
      final Offset scaleStart2 = Offset(childInterior.dx + 20.0, childInterior.dy);
      final Offset scaleEnd1 = Offset(scaleStart1.dx + 5.0, scaleStart1.dy);
      final Offset scaleEnd2 = Offset(scaleStart2.dx - 5.0, scaleStart2.dy);
      gesture = await tester.createGesture();
      final TestGesture gesture2 = await tester.createGesture();
      await gesture.down(scaleStart1);
      await gesture2.down(scaleStart2);
      await tester.pump();
      await gesture.moveTo(scaleEnd1);
      await gesture2.moveTo(scaleEnd2);
      await tester.pump();
      await gesture.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      // The new scale is the scale that makes the original size (200.0) as big
      // as the boundary (220.0).
      expect(transformationController.value.getMaxScaleOnAxis(), 200.0 / 220.0);
    });

    testWidgets('child bigger than viewport', (WidgetTester tester) async {
      final TransformationController transformationController = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveViewer(
                constrained: false,
                scaleEnabled: false,
                transformationController: transformationController,
                child: Container(width: 2000.0, height: 2000.0),
              ),
            ),
          ),
        ),
      );

      expect(transformationController.value, equals(Matrix4.identity()));

      // Attempting to move against the boundary doesn't work.
      final Offset childOffset = tester.getTopLeft(find.byType(Container));
      final Offset childInterior = Offset(
        childOffset.dx + 20.0,
        childOffset.dy + 20.0,
      );
      TestGesture gesture = await tester.startGesture(childOffset);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(childInterior);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(transformationController.value, equals(Matrix4.identity()));

      // Attempting to pinch to zoom doens't work because it's disabled.
      final Offset scaleStart1 = childInterior;
      final Offset scaleStart2 = Offset(childInterior.dx + 10.0, childInterior.dy);
      final Offset scaleEnd1 = Offset(childInterior.dx - 10.0, childInterior.dy);
      final Offset scaleEnd2 = Offset(childInterior.dx + 20.0, childInterior.dy);
      gesture = await tester.startGesture(scaleStart1);
      TestGesture gesture2 = await tester.startGesture(scaleStart2);
      addTearDown(gesture2.removePointer);
      await tester.pump();
      await gesture.moveTo(scaleEnd1);
      await gesture2.moveTo(scaleEnd2);
      await tester.pump();
      await gesture.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(transformationController.value, equals(Matrix4.identity()));

      // Attempting to pinch to rotate doesn't work because it's disabled.
      final Offset rotateStart1 = childInterior;
      final Offset rotateStart2 = Offset(childInterior.dx + 10.0, childInterior.dy);
      final Offset rotateEnd1 = Offset(childInterior.dx + 5.0, childInterior.dy + 5.0);
      final Offset rotateEnd2 = Offset(childInterior.dx - 5.0, childInterior.dy - 5.0);
      gesture = await tester.startGesture(rotateStart1);
      gesture2 = await tester.startGesture(rotateStart2);
      await tester.pump();
      await gesture.moveTo(rotateEnd1);
      await gesture2.moveTo(rotateEnd2);
      await tester.pump();
      await gesture.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(transformationController.value, equals(Matrix4.identity()));

      // Drag to pan away from the boundary.
      gesture = await tester.startGesture(childInterior);
      await tester.pump();
      await gesture.moveTo(childOffset);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(transformationController.value, isNot(equals(Matrix4.identity())));
    });

    testWidgets('no boundary', (WidgetTester tester) async {
      final TransformationController transformationController = TransformationController();
      const double minScale = 0.8;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: minScale,
                transformationController: transformationController,
                child: Container(width: 200.0, height: 200.0),
              ),
            ),
          ),
        ),
      );

      expect(transformationController.value, equals(Matrix4.identity()));

      // Drag to pan works because even though the viewport fits perfectly
      // around the child, there is no boundary.
      final Offset childOffset = tester.getTopLeft(find.byType(Container));
      final Offset childInterior = Offset(
        childOffset.dx + 20.0,
        childOffset.dy + 20.0,
      );
      TestGesture gesture = await tester.startGesture(childInterior);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(childOffset);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final Vector3 translation = transformationController.value.getTranslation();
      expect(translation.x, childOffset.dx - childInterior.dx);
      expect(translation.y, childOffset.dy - childInterior.dy);

      // It's also possible to zoom out and view beyond the child because there
      // is no boundary.
      final Offset scaleStart1 = childInterior;
      final Offset scaleStart2 = Offset(childInterior.dx + 20.0, childInterior.dy);
      final Offset scaleEnd1 = Offset(childInterior.dx + 5.0, childInterior.dy);
      final Offset scaleEnd2 = Offset(childInterior.dx - 5.0, childInterior.dy);
      gesture = await tester.createGesture();
      final TestGesture gesture2 = await tester.createGesture();
      await gesture.down(scaleStart1);
      await gesture2.down(scaleStart2);
      await tester.pump();
      await gesture.moveTo(scaleEnd1);
      await gesture2.moveTo(scaleEnd2);
      await tester.pump();
      await gesture.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(transformationController.value.getMaxScaleOnAxis(), minScale);
    });

    testWidgets('inertia fling and boundary sliding', (WidgetTester tester) async {
      final TransformationController transformationController = TransformationController();
      const double boundaryMargin = 50.0;
      const double minScale = 0.8;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(boundaryMargin),
                minScale: minScale,
                transformationController: transformationController,
                child: Container(width: 200.0, height: 200.0),
              ),
            ),
          ),
        ),
      );

      // Fling the child.
      final Offset childOffset = tester.getTopLeft(find.byType(Container));
      const Offset flingEnd = Offset(20.0, 15.0);
      await tester.flingFrom(childOffset, flingEnd, 1000.0);
      await tester.pump();

      // Immediately after the gesture, the child has moved to exactly follow
      // the gesture.
      Vector3 translation = transformationController.value.getTranslation();
      expect(translation.x, flingEnd.dx);
      expect(translation.y, flingEnd.dy);

      // A short time after the gesture was released, it continues to move with
      // inertia.
      await tester.pump(const Duration(milliseconds: 10));
      translation = transformationController.value.getTranslation();
      expect(translation.x, greaterThan(20.0));
      expect(translation.y, greaterThan(10.0));
      expect(translation.x, lessThan(boundaryMargin));
      expect(translation.y, lessThan(boundaryMargin));

      // It hits the boundary in the x direction first.
      await tester.pump(const Duration(milliseconds: 60));
      translation = transformationController.value.getTranslation();
      expect(translation.x, closeTo(boundaryMargin, .000000001));
      expect(translation.y, lessThan(boundaryMargin));
      final double yWhenXHits = translation.y;

      // x is held to the boundary while y slides along.
      await tester.pump(const Duration(milliseconds: 50));
      translation = transformationController.value.getTranslation();
      expect(translation.x, closeTo(boundaryMargin, .000000001));
      expect(translation.y, greaterThan(yWhenXHits));
      expect(translation.y, lessThan(boundaryMargin));

      // Eventually it ends up in the corner.
      await tester.pumpAndSettle();
      translation = transformationController.value.getTranslation();
      expect(translation.x, closeTo(boundaryMargin, .000000001));
      expect(translation.y, closeTo(boundaryMargin, .000000001));
    });

    testWidgets('Scaling automatically causes a centering translation', (WidgetTester tester) async {
      final TransformationController transformationController = TransformationController();
      const double boundaryMargin = 50.0;
      const double minScale = 0.1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(boundaryMargin),
                minScale: minScale,
                transformationController: transformationController,
                child: Container(width: 200.0, height: 200.0),
              ),
            ),
          ),
        ),
      );

      Vector3 translation = transformationController.value.getTranslation();
      expect(translation.x, 0.0);
      expect(translation.y, 0.0);

      // Pan into the corner of the boundaries.
      final Offset childOffset = tester.getTopLeft(find.byType(Container));
      const Offset flingEnd = Offset(20.0, 15.0);
      await tester.flingFrom(childOffset, flingEnd, 1000.0);
      await tester.pumpAndSettle();
      translation = transformationController.value.getTranslation();
      expect(translation.x, closeTo(boundaryMargin, .000000001));
      expect(translation.y, closeTo(boundaryMargin, .000000001));

      // Zoom out so the entire child is visible. The child will also be
      // translated in order to keep it inside the boundaries.
      final Offset childCenter = tester.getCenter(find.byType(Container));
      Offset scaleStart1 = Offset(childCenter.dx - 40.0, childCenter.dy);
      Offset scaleStart2 = Offset(childCenter.dx + 40.0, childCenter.dy);
      Offset scaleEnd1 = Offset(childCenter.dx - 10.0, childCenter.dy);
      Offset scaleEnd2 = Offset(childCenter.dx + 10.0, childCenter.dy);
      TestGesture gesture = await tester.createGesture();
      TestGesture gesture2 = await tester.createGesture();
      await gesture.down(scaleStart1);
      await gesture2.down(scaleStart2);
      await tester.pump();
      await gesture.moveTo(scaleEnd1);
      await gesture2.moveTo(scaleEnd2);
      await tester.pump();
      await gesture.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(transformationController.value.getMaxScaleOnAxis(), lessThan(1.0));
      translation = transformationController.value.getTranslation();
      expect(translation.x, lessThan(boundaryMargin));
      expect(translation.y, lessThan(boundaryMargin));
      expect(translation.x, greaterThan(0.0));
      expect(translation.y, greaterThan(0.0));
      expect(translation.x, closeTo(translation.y, .000000001));

      // Zoom in on a point that's not the center, and see that it remains at
      // roughly the same location in the viewport after the zoom.
      scaleStart1 = Offset(childCenter.dx - 50.0, childCenter.dy);
      scaleStart2 = Offset(childCenter.dx - 30.0, childCenter.dy);
      scaleEnd1 = Offset(childCenter.dx - 51.0, childCenter.dy);
      scaleEnd2 = Offset(childCenter.dx - 29.0, childCenter.dy);
      final Offset viewportFocalPoint = Offset(
        childCenter.dx - 40.0 - childOffset.dx,
        childCenter.dy - childOffset.dy,
      );
      final Offset sceneFocalPoint = transformationController.toScene(viewportFocalPoint);
      gesture = await tester.createGesture();
      gesture2 = await tester.createGesture();
      await gesture.down(scaleStart1);
      await gesture2.down(scaleStart2);
      await tester.pump();
      await gesture.moveTo(scaleEnd1);
      await gesture2.moveTo(scaleEnd2);
      await tester.pump();
      await gesture.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      final Offset newSceneFocalPoint = transformationController.toScene(viewportFocalPoint);
      expect(newSceneFocalPoint.dx, closeTo(sceneFocalPoint.dx, 1.0));
      expect(newSceneFocalPoint.dy, closeTo(sceneFocalPoint.dy, 1.0));
    });
  });

  group('getNearestPointOnLine', () {
    test('does not modify parameters', () {
      final Vector3 point = Vector3(5.0, 5.0, 0.0);
      final Vector3 a = Vector3(0.0, 0.0, 0.0);
      final Vector3 b = Vector3(10.0, 0.0, 0.0);

      final Vector3 closestPoint = InteractiveViewer.getNearestPointOnLine(point, a , b);

      expect(closestPoint, Vector3(5.0, 0.0, 0.0));
      expect(point, Vector3(5.0, 5.0, 0.0));
      expect(a, Vector3(0.0, 0.0, 0.0));
      expect(b, Vector3(10.0, 0.0, 0.0));
    });

    test('simple example', () {
      final Vector3 point = Vector3(0.0, 5.0, 0.0);
      final Vector3 a = Vector3(0.0, 0.0, 0.0);
      final Vector3 b = Vector3(5.0, 5.0, 0.0);

      expect(InteractiveViewer.getNearestPointOnLine(point, a, b), Vector3(2.5, 2.5, 0.0));
    });

    test('closest to a', () {
      final Vector3 point = Vector3(-1.0, -1.0, 0.0);
      final Vector3 a = Vector3(0.0, 0.0, 0.0);
      final Vector3 b = Vector3(5.0, 5.0, 0.0);

      expect(InteractiveViewer.getNearestPointOnLine(point, a, b), a);
    });

    test('closest to b', () {
      final Vector3 point = Vector3(6.0, 6.0, 0.0);
      final Vector3 a = Vector3(0.0, 0.0, 0.0);
      final Vector3 b = Vector3(5.0, 5.0, 0.0);

      expect(InteractiveViewer.getNearestPointOnLine(point, a, b), b);
    });

    test('point already on the line returns the point', () {
      final Vector3 point = Vector3(2.0, 2.0, 0.0);
      final Vector3 a = Vector3(0.0, 0.0, 0.0);
      final Vector3 b = Vector3(5.0, 5.0, 0.0);

      expect(InteractiveViewer.getNearestPointOnLine(point, a, b), point);
    });

    test('real example', () {
      final Vector3 point = Vector3(-436.9, 433.6, 0.0);
      final Vector3 a = Vector3(-1114.0, -60.3, 0.0);
      final Vector3 b = Vector3(288.8, 432.7, 0.0);

      final Vector3 closestPoint = InteractiveViewer.getNearestPointOnLine(point, a , b);

      expect(closestPoint.x, closeTo(-356.8, 0.1));
      expect(closestPoint.y, closeTo(205.8, 0.1));
    });
  });

  group('getAxisAlignedBoundingBox', () {
    test('rectangle already axis aligned returns the rectangle', () {
      final Quad quad = Quad.points(
        Vector3(0.0, 0.0, 0.0),
        Vector3(10.0, 0.0, 0.0),
        Vector3(10.0, 10.0, 0.0),
        Vector3(0.0, 10.0, 0.0),
      );

      final Quad aabb = InteractiveViewer.getAxisAlignedBoundingBox(quad);

      expect(aabb.point0, quad.point0);
      expect(aabb.point1, quad.point1);
      expect(aabb.point2, quad.point2);
      expect(aabb.point3, quad.point3);
    });

    test('rectangle rotated by 45 degrees', () {
      final Quad quad = Quad.points(
        Vector3(0.0, 5.0, 0.0),
        Vector3(5.0, 10.0, 0.0),
        Vector3(10.0, 5.0, 0.0),
        Vector3(5.0, 0.0, 0.0),
      );

      final Quad aabb = InteractiveViewer.getAxisAlignedBoundingBox(quad);

      expect(aabb.point0, Vector3(0.0, 0.0, 0.0));
      expect(aabb.point1, Vector3(10.0, 0.0, 0.0));
      expect(aabb.point2, Vector3(10.0, 10.0, 0.0));
      expect(aabb.point3, Vector3(0.0, 10.0, 0.0));
    });

    test('rectangle rotated very slightly', () {
      final Quad quad = Quad.points(
        Vector3(0.0, 1.0, 0.0),
        Vector3(1.0, 11.0, 0.0),
        Vector3(11.0, 9.0, 0.0),
        Vector3(9.0, -1.0, 0.0),
      );

      final Quad aabb = InteractiveViewer.getAxisAlignedBoundingBox(quad);

      expect(aabb.point0, Vector3(0.0, -1.0, 0.0));
      expect(aabb.point1, Vector3(11.0, -1.0, 0.0));
      expect(aabb.point2, Vector3(11.0, 11.0, 0.0));
      expect(aabb.point3, Vector3(0.0, 11.0, 0.0));
    });

    test('example from hexagon board', () {
      final Quad quad = Quad.points(
        Vector3(-462.7, 165.9, 0.0),
        Vector3(690.6, -576.7, 0.0),
        Vector3(1188.1, 196.0, 0.0),
        Vector3(34.9, 938.6, 0.0),
      );

      final Quad aabb = InteractiveViewer.getAxisAlignedBoundingBox(quad);

      expect(aabb.point0, Vector3(-462.7, -576.7, 0.0));
      expect(aabb.point1, Vector3(1188.1, -576.7, 0.0));
      expect(aabb.point2, Vector3(1188.1, 938.6, 0.0));
      expect(aabb.point3, Vector3(-462.7, 938.6, 0.0));
    });
  });

  group('pointIsInside', () {
    test('inside', () {
      final Quad quad = Quad.points(
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 10.0, 0.0),
        Vector3(10.0, 10.0, 0.0),
        Vector3(10.0, 0.0, 0.0),
      );
      final Vector3 point = Vector3(5.0, 5.0, 0.0);

      expect(InteractiveViewer.pointIsInside(point, quad), true);
    });

    test('outside', () {
      final Quad quad = Quad.points(
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 10.0, 0.0),
        Vector3(10.0, 10.0, 0.0),
        Vector3(10.0, 0.0, 0.0),
      );
      final Vector3 point = Vector3(12.0, 0.0, 0.0);

      expect(InteractiveViewer.pointIsInside(point, quad), false);
    });

    test('on the edge', () {
      final Quad quad = Quad.points(
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 10.0, 0.0),
        Vector3(10.0, 10.0, 0.0),
        Vector3(10.0, 0.0, 0.0),
      );
      final Vector3 point = Vector3(0.0, 0.0, 0.0);

      expect(InteractiveViewer.pointIsInside(point, quad), true);
    });
  });

  group('getNearestPointInside', () {
    test('point already inside quad', () {
      final Vector3 point = Vector3(5.0, 5.0, 0.0);
      final Quad quad = Quad.points(
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 10.0, 0.0),
        Vector3(10.0, 10.0, 0.0),
        Vector3(10.0, 0.0, 0.0),
      );

      final Vector3 nearestPoint = InteractiveViewer.getNearestPointInside(point, quad);

      expect(nearestPoint, point);
    });

    test('axis aligned quad', () {
      final Vector3 point = Vector3(5.0, 15.0, 0.0);
      final Quad quad = Quad.points(
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 10.0, 0.0),
        Vector3(10.0, 10.0, 0.0),
        Vector3(10.0, 0.0, 0.0),
      );

      final Vector3 nearestPoint = InteractiveViewer.getNearestPointInside(point, quad);

      expect(nearestPoint, Vector3(5.0, 10.0, 0.0));
    });

    test('not axis aligned quad', () {
      final Vector3 point = Vector3(5.0, 15.0, 0.0);
      final Quad quad = Quad.points(
        Vector3(0.0, 0.0, 0.0),
        Vector3(2.0, 10.0, 0.0),
        Vector3(12.0, 12.0, 0.0),
        Vector3(10.0, 2.0, 0.0),
      );

      final Vector3 nearestPoint = InteractiveViewer.getNearestPointInside(point, quad);

      expect(nearestPoint.x, closeTo(5.8, 0.1));
      expect(nearestPoint.y, closeTo(10.8, 0.1));
    });
  });
}
