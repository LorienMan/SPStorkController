// The MIT License (MIT)
// Copyright © 2017 Ivan Vorobei (hello@ivanvorobei.by)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

final class SPStorkPresentingAnimationController: NSObject, UIViewControllerAnimatedTransitioning {

    var currentTransitionContext: UIViewControllerContextTransitioning?
    var finishAnimationTime: TimeInterval = 0
    var animationStartY: CGFloat = 0

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        currentTransitionContext = transitionContext

        guard let presentedViewController = transitionContext.viewController(forKey: .to) else {
            return
        }

        let containerView = transitionContext.containerView
        containerView.addSubview(presentedViewController.view)

        let finalFrameForPresentedView = transitionContext.finalFrame(for: presentedViewController)
        presentedViewController.view.frame = finalFrameForPresentedView
        animationStartY = containerView.bounds.height
        presentedViewController.view.frame.origin.y = animationStartY

        (presentedViewController.presentationController as? SPStorkPresentationController)?.activePresentingAnimationController = self

        finishAnimationTime = ProcessInfo.processInfo.systemUptime + transitionDuration(using: transitionContext)
        animateTo(finalFrameForPresentedView)
    }

    var animationsCount: Int = 0

    func animateTo(_ frame: CGRect) {
        guard let transitionContext = currentTransitionContext,
              let presentedViewController = transitionContext.viewController(forKey: .to) else {
            return
        }

        animationsCount += 1
        let currentAnimationIdx = animationsCount

        let originalFrame = presentedViewController.view.frame
        var currentFrame = frame
        currentFrame.origin.y = presentedViewController.view.layer.presentation()?.frame.origin.y ?? animationStartY

        let shouldLayout = originalFrame.size != currentFrame.size
        presentedViewController.view.layer.removeAllAnimations()
        presentedViewController.view.frame = currentFrame

        if shouldLayout {
            presentedViewController.view.frame = frame
            presentedViewController.view.setNeedsLayout()
            presentedViewController.view.layoutIfNeeded()

            presentedViewController.view.frame = currentFrame
        }

        if currentAnimationIdx != animationsCount {
            return
        }

        UIView.animate(
                withDuration: max(finishAnimationTime - ProcessInfo.processInfo.systemUptime, 0),
                delay: 0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: 1,
                options: [.curveEaseOut, .beginFromCurrentState],
                animations: {
                    presentedViewController.view.frame = frame
                }, completion: { finished in
            if self.animationsCount == currentAnimationIdx {
                self.currentTransitionContext = nil
                (presentedViewController.presentationController as? SPStorkPresentationController)?.activePresentingAnimationController = nil
                transitionContext.completeTransition(finished)
            }
        })
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.6
    }
}

