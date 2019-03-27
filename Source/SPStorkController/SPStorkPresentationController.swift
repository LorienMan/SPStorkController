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

@objc
public protocol SPStorkPresentationControllerProtocol: class {
    var scaleEnabled: Bool { get set }
    var frictionEnabled: Bool { get set }
    var scrollView: UIScrollView? { get set }

    func updateCustomHeight(_ customHeight: CGFloat)
    func updatePresentingController()
}

@objc
public protocol SPStorkPresentationControllerRelatedViewController: class {
    @objc optional func storkPresentationControllerWillDismiss(_ presentationController: SPStorkPresentationControllerProtocol, presentedViewController: UIViewController)
    @objc optional func storkPresentationControllerDidDismiss(_ presentationController: SPStorkPresentationControllerProtocol, presentedViewController: UIViewController)

    @objc optional func storkPresentationControllerDidStartInteractiveDismissal(_ presentationController: SPStorkPresentationControllerProtocol, presentedViewController: UIViewController)
    @objc optional func storkPresentationControllerDidFinishInteractiveDismissal(_ presentationController: SPStorkPresentationControllerProtocol, presentedViewController: UIViewController, willDismiss: Bool)

    @objc optional func storkPresentationControllerShouldStartInteractiveDismissal(_ presentationController: SPStorkPresentationControllerProtocol, presentedViewController: UIViewController) -> Bool
}

class SPStorkPresentationController: UIPresentationController, UIGestureRecognizerDelegate, SPStorkPresentationControllerProtocol {

    var swipeToDismissEnabled: Bool = true
    var tapAroundToDismissEnabled: Bool = true
    var showIndicator: Bool = true
    var indicatorColor: UIColor = UIColor.init(red: 202 / 255, green: 201 / 255, blue: 207 / 255, alpha: 1)
    var customHeight: CGFloat? = nil
    var translateForDismiss: CGFloat = 240
    var scaleEnabled: Bool = true
    var frictionEnabled: Bool = true
    var useSnapshot: Bool = true

    var scrollView: UIScrollView? {
        didSet {
            setupNewCustomScrollViewPan()
        }
    }

    var transitioningDelegate: SPStorkTransitioningDelegate?

    private(set) var pan: UIPanGestureRecognizer?
    private(set) var tap: UITapGestureRecognizer?
    private(set) var customScrollViewPan: UIPanGestureRecognizer?

    private var indicatorView = SPStorkIndicatorView()
    private var gradeView: UIView = UIView()
    private let snapshotViewContainer = UIView()
    private var snapshotView: UIView?
    private let backgroundView = UIView()

    private var snapshotViewTopConstraint: NSLayoutConstraint?
    private var snapshotViewWidthConstraint: NSLayoutConstraint?
    private var snapshotViewAspectRatioConstraint: NSLayoutConstraint?
    private var startDismissing: Bool = false
    private var currentTranslation: CGFloat = 0
    private var scrollViewAdjustment: CGFloat = 0

    private var topSpace: CGFloat {
        let statusBarHeight: CGFloat = UIApplication.shared.statusBarFrame.height
        return (statusBarHeight < 25) ? 30 : statusBarHeight
    }

    private var alpha: CGFloat {
        return 0.51
    }

    private var cornerRadius: CGFloat {
        return 10
    }

    private var scaleForPresentingView: CGFloat {
        if scaleEnabled {
            guard let containerView = containerView else {
                return 0
            }

            let factor = 1 - (self.topSpace * 2 / containerView.frame.height)
            return factor
        }

        return 1
    }

    private var contentHeightAdjustment: CGFloat {
        return self.topSpace + 13
    }

    weak var activePresentingAnimationController: SPStorkPresentingAnimationController?

    func updateCustomHeight(_ customHeight: CGFloat) {
        guard customHeight + contentHeightAdjustment != self.customHeight else {
            return
        }

        self.customHeight = customHeight + contentHeightAdjustment

        guard let containerView = self.containerView, containerView.window != nil else {
            return
        }

        if let activePresentingAnimationController = activePresentingAnimationController {
            activePresentingAnimationController.animateTo(frameOfPresentedViewInContainerView)
        } else {
            containerView.setNeedsLayout()
        }
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else {
            return .zero
        }

        var customHeight = self.customHeight ?? containerView.bounds.height
        if customHeight > containerView.bounds.height {
            customHeight = containerView.bounds.height
            print("SPStorkController - Custom height change to default value. Your height more maximum value")
        }
        let additionTranslate = containerView.bounds.height - customHeight
        let yOffset: CGFloat = self.topSpace + 13 + additionTranslate
        return CGRect(x: 0, y: yOffset, width: containerView.bounds.width, height: containerView.bounds.height - yOffset)
    }

    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()

        guard let containerView = self.containerView, let presentedView = self.presentedView, let window = containerView.window else {
            return
        }

        if self.showIndicator {
            self.indicatorView.color = self.indicatorColor
            let tap = UITapGestureRecognizer.init(target: self, action: #selector(self.dismissAction))
            tap.cancelsTouchesInView = false
            self.indicatorView.addGestureRecognizer(tap)
            presentedView.addSubview(self.indicatorView)
        }
        self.updateLayoutIndicator()
        self.indicatorView.style = .arrow
        self.gradeView.alpha = 0

        let initialFrame: CGRect = presentingViewController.isPresentedAsStork ? presentingViewController.view.frame : containerView.bounds

        containerView.insertSubview(self.snapshotViewContainer, belowSubview: presentedViewController.view)
        self.snapshotViewContainer.frame = initialFrame
        self.updateSnapshot()
        self.snapshotView?.layer.cornerRadius = 0
        self.backgroundView.backgroundColor = useSnapshot ? UIColor.black : UIColor.clear
        self.backgroundView.translatesAutoresizingMaskIntoConstraints = false
        containerView.insertSubview(self.backgroundView, belowSubview: self.snapshotViewContainer)
        NSLayoutConstraint.activate([
            self.backgroundView.topAnchor.constraint(equalTo: window.topAnchor),
            self.backgroundView.leftAnchor.constraint(equalTo: window.leftAnchor),
            self.backgroundView.rightAnchor.constraint(equalTo: window.rightAnchor),
            self.backgroundView.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])

        let transformForSnapshotView: CGAffineTransform

        if scaleEnabled {
            transformForSnapshotView = CGAffineTransform.identity
                    .translatedBy(x: 0, y: -snapshotViewContainer.frame.origin.y)
                    .translatedBy(x: 0, y: self.topSpace)
                    .translatedBy(x: 0, y: -snapshotViewContainer.frame.height / 2)
                    .scaledBy(x: scaleForPresentingView, y: scaleForPresentingView)
                    .translatedBy(x: 0, y: snapshotViewContainer.frame.height / 2)
        } else {
            transformForSnapshotView = CGAffineTransform.identity
        }

        self.addCornerRadiusAnimation(for: self.snapshotView, cornerRadius: self.cornerRadius, duration: 0.6)
        self.snapshotView?.layer.masksToBounds = true
        if #available(iOS 11.0, *) {
            presentedView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        presentedView.layer.cornerRadius = self.cornerRadius
        presentedView.layer.masksToBounds = true

        var rootSnapshotView: UIView?
        var rootSnapshotRoundedView: UIView?

        if presentingViewController.isPresentedAsStork {
            guard let rootController = presentingViewController.presentingViewController, let snapshotView = useSnapshot ? rootController.view.snapshotView(afterScreenUpdates: false) : UIView() else {
                return
            }

            containerView.insertSubview(snapshotView, aboveSubview: self.backgroundView)
            snapshotView.frame = initialFrame
            snapshotView.transform = transformForSnapshotView
            snapshotView.alpha = self.alpha
            snapshotView.layer.cornerRadius = self.cornerRadius
            snapshotView.layer.masksToBounds = true
            rootSnapshotView = snapshotView

            let snapshotRoundedView = UIView()
            snapshotRoundedView.layer.cornerRadius = self.cornerRadius
            snapshotRoundedView.layer.masksToBounds = true
            containerView.insertSubview(snapshotRoundedView, aboveSubview: snapshotView)
            snapshotRoundedView.frame = initialFrame
            snapshotRoundedView.transform = transformForSnapshotView
            rootSnapshotRoundedView = snapshotRoundedView
        }

        presentedViewController.transitionCoordinator?.animate(
                alongsideTransition: { [weak self] context in
                    guard let `self` = self else {
                        return
                    }
                    self.snapshotView?.transform = transformForSnapshotView
                    self.gradeView.alpha = self.alpha
                }, completion: { _ in
            self.snapshotView?.transform = .identity
            rootSnapshotView?.removeFromSuperview()
            rootSnapshotRoundedView?.removeFromSuperview()
        })
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        guard let containerView = containerView else {
            return
        }
        self.updateSnapshot()
        self.presentedViewController.view.frame = self.frameOfPresentedViewInContainerView
        self.snapshotViewContainer.transform = .identity
        self.snapshotViewContainer.translatesAutoresizingMaskIntoConstraints = false
        self.snapshotViewContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
        self.updateSnapshotAspectRatio()

        if self.tapAroundToDismissEnabled {
            self.tap = UITapGestureRecognizer.init(target: self, action: #selector(self.dismissAction))
            self.tap?.cancelsTouchesInView = false
            self.snapshotViewContainer.addGestureRecognizer(self.tap!)
        }

        if self.swipeToDismissEnabled {
            self.pan = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan))
            self.pan!.delegate = self
            self.pan!.maximumNumberOfTouches = 1
            self.pan!.cancelsTouchesInView = false
            self.presentedViewController.view.addGestureRecognizer(self.pan!)
        }

        setupNewCustomScrollViewPan()
    }

    private func setupNewCustomScrollViewPan() {
        guard swipeToDismissEnabled else {
            return
        }

        if let customScrollViewPan = customScrollViewPan {
            customScrollViewPan.view?.removeGestureRecognizer(customScrollViewPan)
        }

        self.customScrollViewPan = UIPanGestureRecognizer(target: self, action: #selector(self.handleScrollViewPan))
        self.customScrollViewPan!.delegate = self
        self.customScrollViewPan!.maximumNumberOfTouches = 1
        self.customScrollViewPan!.cancelsTouchesInView = false
        scrollView?.addGestureRecognizer(self.customScrollViewPan!)
    }

    @objc func dismissAction() {
        self.presentedViewController.dismiss(animated: true, completion: nil)
    }

    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        guard let containerView = containerView else {
            return
        }

        self.startDismissing = true

        let initialFrame: CGRect = presentingViewController.isPresentedAsStork ? presentingViewController.view.frame : containerView.bounds

        let initialTransform: CGAffineTransform
        if scaleEnabled {
            initialTransform = CGAffineTransform.identity
                    .translatedBy(x: 0, y: -initialFrame.origin.y)
                    .translatedBy(x: 0, y: self.topSpace)
                    .translatedBy(x: 0, y: -initialFrame.height / 2)
                    .scaledBy(x: scaleForPresentingView, y: scaleForPresentingView)
                    .translatedBy(x: 0, y: initialFrame.height / 2)
        } else {
            initialTransform = CGAffineTransform.identity
        }

        self.snapshotViewTopConstraint?.isActive = false
        self.snapshotViewWidthConstraint?.isActive = false
        self.snapshotViewAspectRatioConstraint?.isActive = false
        self.snapshotViewContainer.translatesAutoresizingMaskIntoConstraints = true
        self.snapshotViewContainer.frame = initialFrame
        self.snapshotViewContainer.transform = initialTransform

        let finalCornerRadius = presentingViewController.isPresentedAsStork ? self.cornerRadius : 0
        let finalTransform: CGAffineTransform = .identity

        self.addCornerRadiusAnimation(for: self.snapshotView, cornerRadius: finalCornerRadius, duration: 0.6)

        var rootSnapshotView: UIView?
        var rootSnapshotRoundedView: UIView?

        if presentingViewController.isPresentedAsStork {
            guard let rootController = presentingViewController.presentingViewController,
                  let snapshotView = useSnapshot ? rootController.view.snapshotView(afterScreenUpdates: false) : UIView() else {
                return
            }

            containerView.insertSubview(snapshotView, aboveSubview: backgroundView)
            snapshotView.frame = initialFrame
            snapshotView.transform = initialTransform
            rootSnapshotView = snapshotView
            snapshotView.layer.cornerRadius = self.cornerRadius
            snapshotView.layer.masksToBounds = true

            let snapshotRoundedView = UIView()
            snapshotRoundedView.layer.cornerRadius = self.cornerRadius
            snapshotRoundedView.layer.masksToBounds = true
            snapshotRoundedView.backgroundColor = UIColor.black.withAlphaComponent(1 - self.alpha)
            containerView.insertSubview(snapshotRoundedView, aboveSubview: snapshotView)
            snapshotRoundedView.frame = initialFrame
            snapshotRoundedView.transform = initialTransform
            rootSnapshotRoundedView = snapshotRoundedView
        }

        presentedViewController.transitionCoordinator?.animate(
                alongsideTransition: { [weak self] context in
                    guard let `self` = self else {
                        return
                    }
                    self.snapshotView?.transform = .identity
                    self.snapshotViewContainer.transform = finalTransform
                    self.gradeView.alpha = 0
                }, completion: { _ in
            rootSnapshotView?.removeFromSuperview()
            rootSnapshotRoundedView?.removeFromSuperview()
        })
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        guard let containerView = containerView else {
            return
        }

        self.backgroundView.removeFromSuperview()
        self.snapshotView?.removeFromSuperview()
        self.snapshotViewContainer.removeFromSuperview()

        let offscreenFrame = CGRect(x: 0, y: containerView.bounds.height, width: containerView.bounds.width, height: containerView.bounds.height)
        presentedViewController.view.frame = offscreenFrame
        presentedViewController.view.transform = .identity
    }
}

extension SPStorkPresentationController {

    @objc func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(self.pan), self.swipeToDismissEnabled else {
            return
        }

        switch gestureRecognizer.state {
        case .began:
            (presentedViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidStartInteractiveDismissal?(self, presentedViewController: presentedViewController)
            (presentingViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidStartInteractiveDismissal?(self, presentedViewController: presentedViewController)

            self.indicatorView.style = .line
            self.presentingViewController.view.layer.removeAllAnimations()
            gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: containerView)
            currentTranslation = 0
        case .changed:
            if self.swipeToDismissEnabled {
                let translation = gestureRecognizer.translation(in: presentedView)
                self.updatePresentedViewForTranslation(inVerticalDirection: translation.y)
            } else {
                gestureRecognizer.setTranslation(.zero, in: presentedView)
            }
        case .ended:
            let translation = gestureRecognizer.translation(in: presentedView).y
            if translation >= self.translateForDismiss {
                (presentedViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidFinishInteractiveDismissal?(self, presentedViewController: presentedViewController, willDismiss: true)
                (presentingViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidFinishInteractiveDismissal?(self, presentedViewController: presentedViewController, willDismiss: true)
                presentedViewController.dismiss(animated: true, completion: nil)
            } else {
                (presentedViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidFinishInteractiveDismissal?(self, presentedViewController: presentedViewController, willDismiss: false)
                (presentingViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidFinishInteractiveDismissal?(self, presentedViewController: presentedViewController, willDismiss: false)
                self.indicatorView.style = .arrow
                UIView.animate(
                        withDuration: 0.6,
                        delay: 0,
                        usingSpringWithDamping: 1,
                        initialSpringVelocity: 1,
                        options: [.curveEaseOut, .allowUserInteraction],
                        animations: {
                            self.snapshotView?.transform = .identity
                            self.presentedView?.transform = .identity
                            self.gradeView.alpha = self.alpha
                        })
            }
        default:
            break
        }
    }

    @objc func handleScrollViewPan(gestureRecognizer: UIPanGestureRecognizer) {
        guard let scrollView = scrollView else {
            return
        }

        switch gestureRecognizer.state {
        case .began:
            (presentedViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidStartInteractiveDismissal?(self, presentedViewController: presentedViewController)
            (presentingViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidStartInteractiveDismissal?(self, presentedViewController: presentedViewController)

            let topContentInset: CGFloat

            if #available(iOS 11.0, *) {
                topContentInset = scrollView.adjustedContentInset.top
            } else {
                topContentInset = scrollView.contentInset.top
            }

            currentTranslation = 0
            let translation = gestureRecognizer.translation(in: containerView)
            scrollViewAdjustment = max(scrollView.contentOffset.y + topContentInset - translation.y, 0)

            self.indicatorView.style = .line
            self.presentingViewController.view.layer.removeAllAnimations()

        case .changed:
            if self.swipeToDismissEnabled {
                let translation = gestureRecognizer.translation(in: containerView).y - scrollViewAdjustment

                let previousTranslation = currentTranslation
                self.updatePresentedViewForTranslation(inVerticalDirection: translation)

                let allowedStates: [UIGestureRecognizer.State] = [.began, .changed]
                if allowedStates.contains(scrollView.panGestureRecognizer.state) {
                    var adjustedContentOffset = scrollView.contentOffset
                    adjustedContentOffset.y += currentTranslation - previousTranslation
                    scrollView.contentOffset = adjustedContentOffset
                }
            } else {
                gestureRecognizer.setTranslation(.zero, in: containerView)
            }
        case .ended:
            let translation = gestureRecognizer.translation(in: containerView).y - scrollViewAdjustment
            if translation >= self.translateForDismiss {
                (presentedViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidFinishInteractiveDismissal?(self, presentedViewController: presentedViewController, willDismiss: true)
                (presentingViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidFinishInteractiveDismissal?(self, presentedViewController: presentedViewController, willDismiss: true)
                presentedViewController.dismiss(animated: true, completion: nil)
            } else {
                (presentedViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidFinishInteractiveDismissal?(self, presentedViewController: presentedViewController, willDismiss: false)
                (presentingViewController as? SPStorkPresentationControllerRelatedViewController)?.storkPresentationControllerDidFinishInteractiveDismissal?(self, presentedViewController: presentedViewController, willDismiss: false)
                self.indicatorView.style = .arrow
                UIView.animate(
                        withDuration: 0.6,
                        delay: 0,
                        usingSpringWithDamping: 1,
                        initialSpringVelocity: 1,
                        options: [.curveEaseOut, .allowUserInteraction],
                        animations: {
                            self.snapshotView?.transform = .identity
                            self.presentedView?.transform = .identity
                            self.gradeView.alpha = self.alpha
                        })
            }

        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === pan || gestureRecognizer === customScrollViewPan {
            if let presentedRelatedViewController = presentedViewController as? SPStorkPresentationControllerRelatedViewController,
               let method = presentedRelatedViewController.storkPresentationControllerShouldStartInteractiveDismissal {
                return method(self, presentedViewController)
            } else {
                return true
            }
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === scrollView?.panGestureRecognizer && otherGestureRecognizer === customScrollViewPan {
            return true
        } else if gestureRecognizer === customScrollViewPan && otherGestureRecognizer === scrollView?.panGestureRecognizer {
            return true
        }

        return false
    }

    func updatePresentingController() {
        self.updateSnapshot()
    }

    private func finalTranslation(for translation: CGFloat) -> CGFloat {
        var translationForModal: CGFloat
        if frictionEnabled {
            let elasticThreshold: CGFloat = 120
            let translationFactor: CGFloat = 1 / 2

            translationForModal = {
                if translation >= elasticThreshold {
                    let frictionLength = translation - elasticThreshold
                    let frictionTranslation = 30 * atan(frictionLength / 120) + frictionLength / 10
                    return frictionTranslation + (elasticThreshold * translationFactor)
                } else {
                    return translation * translationFactor
                }
            }()
        } else {
            translationForModal = max(translation, 0)
        }

        translationForModal = roundToPixel(translationForModal)

        return translationForModal
    }

    private func updatePresentedViewForTranslation(inVerticalDirection translation: CGFloat) {
        if self.startDismissing {
            return
        }

        let translationForModal = finalTranslation(for: translation)

        self.presentedView?.transform = CGAffineTransform(translationX: 0, y: translationForModal)

        let factor = 1 + (translationForModal / 6000)
        self.snapshotView?.transform = scaleEnabled ? CGAffineTransform.init(scaleX: factor, y: factor) : .identity
        self.gradeView.alpha = self.alpha - ((factor - 1) * 15)

        currentTranslation = translationForModal
    }

    func roundToPixel(_ value: CGFloat) -> CGFloat {
        let screenScale = UIScreen.main.scale
        return round(value * screenScale) / screenScale
    }
}

extension SPStorkPresentationController {

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard let containerView = containerView else {
            return
        }
        self.updateSnapshotAspectRatio()
        if presentedViewController.view.isDescendant(of: containerView) {
            UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: { [weak self] in
                guard let `self` = self else {
                    return
                }

                self.presentedViewController.view.frame = self.frameOfPresentedViewInContainerView
            })
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { context in
            self.updateLayoutIndicator()
        }, completion: { [weak self] _ in
            self?.updateSnapshotAspectRatio()
            self?.updateSnapshot()
        })
    }

    private func updateLayoutIndicator() {
        guard let presentedView = self.presentedView else {
            return
        }
        self.indicatorView.style = .line
        self.indicatorView.sizeToFit()
        self.indicatorView.frame.origin.y = 12
        self.indicatorView.center.x = presentedView.frame.width / 2
    }

    private func updateSnapshot() {
        guard let currentSnapshotView = useSnapshot ? presentingViewController.view.snapshotView(afterScreenUpdates: false) : UIView() else {
            return
        }
        self.snapshotView?.removeFromSuperview()
        self.snapshotViewContainer.addSubview(currentSnapshotView)
        self.constraints(view: currentSnapshotView, to: self.snapshotViewContainer)
        self.snapshotView = currentSnapshotView
        self.snapshotView?.layer.cornerRadius = self.cornerRadius
        self.snapshotView?.layer.masksToBounds = true
        if #available(iOS 11.0, *) {
            snapshotView?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        self.gradeView.removeFromSuperview()
        self.gradeView.backgroundColor = UIColor.black
        self.snapshotView!.addSubview(self.gradeView)
        self.constraints(view: self.gradeView, to: self.snapshotView!)
    }

    private func updateSnapshotAspectRatio() {
        guard let containerView = containerView, snapshotViewContainer.translatesAutoresizingMaskIntoConstraints == false else {
            return
        }

        self.snapshotViewTopConstraint?.isActive = false
        self.snapshotViewWidthConstraint?.isActive = false
        self.snapshotViewAspectRatioConstraint?.isActive = false

        let snapshotReferenceSize = presentingViewController.view.frame.size
        let aspectRatio = snapshotReferenceSize.width / snapshotReferenceSize.height

        self.snapshotViewTopConstraint = snapshotViewContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: scaleEnabled ? self.topSpace : 0)
        self.snapshotViewWidthConstraint = snapshotViewContainer.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: scaleForPresentingView)
        self.snapshotViewAspectRatioConstraint = snapshotViewContainer.widthAnchor.constraint(equalTo: snapshotViewContainer.heightAnchor, multiplier: aspectRatio)

        self.snapshotViewTopConstraint?.isActive = true
        self.snapshotViewWidthConstraint?.isActive = true
        self.snapshotViewAspectRatioConstraint?.isActive = true
    }

    private func constraints(view: UIView, to superView: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: superView.topAnchor),
            view.leftAnchor.constraint(equalTo: superView.leftAnchor),
            view.rightAnchor.constraint(equalTo: superView.rightAnchor),
            view.bottomAnchor.constraint(equalTo: superView.bottomAnchor)
        ])
    }

    private func addCornerRadiusAnimation(for view: UIView?, cornerRadius: CGFloat, duration: CFTimeInterval) {
        guard let view = view else {
            return
        }
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        animation.fromValue = view.layer.cornerRadius
        animation.toValue = cornerRadius
        animation.duration = duration
        view.layer.add(animation, forKey: "cornerRadius")
        view.layer.cornerRadius = cornerRadius
    }
}
