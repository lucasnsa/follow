import 'package:animations/animations.dart';
import 'package:follow/follow.dart';

/// The app chooses its animation package; Follow only consumes Flutter builders.
final sharedAxisTransition = FollowTransition.custom(
  builder: (context, animation, secondaryAnimation, child) =>
      SharedAxisTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    transitionType: SharedAxisTransitionType.horizontal,
    child: child,
  ),
);

final fadeThroughBranches = BranchTransition.custom(
  builder: (context, animation, secondaryAnimation, child) =>
      FadeThroughTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
  ),
);
