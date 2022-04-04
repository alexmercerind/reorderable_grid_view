import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:reorderable_grid_view/src/reorderable_grid_mixin.dart';

/// I only need get the pos of other children.
/// How to pass (or access) the pos delegate?
/// Can I pass the pos delegate to all the child(the same to all)?
/// But for now, let's just do it.
class ReorderableItemView extends StatefulWidget {
  final Widget child;
  final Key key;
  final int index;

  const ReorderableItemView({
    required this.child,
    required this.key,
    required this.index,
  }) : super(key: key);

  static List<Widget> wrapMeList(List<Widget> children,
      List<Widget>? footer) {
    var rst = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      var child = children[i];
      rst.add(ReorderableItemView(
        child: child,
        key: child.key!,
        index: i,
      ));
    }

    rst.addAll(footer ?? []);
    return rst;
  }

  @override
  ReorderableItemViewState createState() => ReorderableItemViewState();
}

class ReorderableItemViewState extends State<ReorderableItemView> with TickerProviderStateMixin {
  late ReorderableGridStateMixin _listState;

  Key get key => widget.key;

  Widget get child => widget.child;

  int get index => widget.index;

  bool get dragging => _dragging;

  set dragging(bool dragging) {
    if (mounted) {
      this.setState(() {
        _dragging = dragging;
      });
    }
  }

  bool _dragging = false;

  /// We can only check the items between startIndex and the targetIndex, but for simply, we check all <= targetDropIndex
  void updateForGap(int targetDropIndex) {
    // Actually I can use only use the targetDropIndex to decide the target pos, but what to do I change middle
    if (!mounted) return;
    // How can I calculate the target?

    // let's try use dragSize.
    Offset newOffset = _listState.getOffsetInDrag(this.index);
    if (newOffset != _targetOffset) {
      _targetOffset = newOffset;

      if (this._offsetAnimation == null) {
        this._offsetAnimation = AnimationController(vsync: _listState)
          ..duration = Duration(milliseconds: 250)
          ..addListener(rebuild)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _startOffset = _targetOffset;
              this._offsetAnimation?.dispose();
              this._offsetAnimation = null;
            }
          })
          ..forward(from: 0.0);
      } else {
        // 调转方向
        _startOffset = offset;
        this._offsetAnimation?.forward(from: 0.0);
      }
    }
  }

  void resetGap() {
    if (_offsetAnimation != null) {
      _offsetAnimation!.dispose();
      _offsetAnimation = null;
    }

    _startOffset = Offset.zero;
    _targetOffset = Offset.zero;
    rebuild();
  }

  // Ok, for now we use multiDragRecognizer
  MultiDragGestureRecognizer _createDragRecognizer() {
    return (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ? ImmediateMultiDragGestureRecognizer(debugOwner: this): DelayedMultiDragGestureRecognizer(debugOwner: this);
  }

  @override
  void initState() {
    _listState = ReorderableGridStateMixin.of(context);
    _listState.registerItem(this);
    super.initState();
  }

  // ths is strange thing.
  Offset _startOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;

  // Ok, how can we calculate the _offsetAnimation
  AnimationController? _offsetAnimation;

  Offset get offset {
    if (_offsetAnimation != null) {
      return Offset.lerp(_startOffset, _targetOffset,
          Curves.easeInOut.transform(_offsetAnimation!.value))!;
    }
    return _targetOffset;
  }

  @override
  void dispose() {
    _listState.unRegisterItem(this.index, this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReorderableItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _listState.unRegisterItem(oldWidget.index, this);
      _listState.registerItem(this);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dragging) {
      // _debug("pos $index is dragging.");
      return SizedBox();
    }

    Widget _buildChild(Widget child) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (_dragging) {
            // why put you in the Listener??
            return SizedBox();
          }

          final _offset = offset;
          return Transform(
            // you are strange.
            transform: Matrix4.translationValues(_offset.dx, _offset.dy, 0),
            child: child,
          );
        },
      );
    }

    return Listener(
      onPointerDown: (PointerDownEvent e) {
        // remember th pointer down??
        // _debug("onPointerDown at $index");
        var listState = ReorderableGridStateMixin.of(context);
        listState.startDragRecognizer(index, e, _createDragRecognizer());
      },
      child: _buildChild(child),
    );
  }

  void rebuild() {
    // _debug("rebuild called for index: ${this.index}, mounted: ${mounted}");
    if (mounted) {
      setState(() {});
    }
  }
}
