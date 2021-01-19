//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport

class MyViewController : UIViewController {
    
    var tapGestureRecognizer: UITapGestureRecognizer!
    // UIPanGestureRecognizer for an experimental "parallax"-like perspective skew
    // when dragging the checkbox before lifting the finger/click. Behavior is still
    // funky since the checkbox's anchor point is not its center.
    // var panGestureRecognizer: UIGestureRecognizer!
    
    var isChecked: Bool = false
    
    var segmentLayers = [CAShapeLayer]()
    let containerView = UIView(frame: CGRect(x: 150, y: 150, width: 100, height: 100))
    let subView = UIView(frame: .zero)
    
    let radius = CGFloat(50)
    let borderWidth = CGFloat(10)
    let numberOfSegments = 6
    
    // The 6 bezier curves allow for 1, 2, 3 or 6 different colors since 6 mod {1,2,3,6} = 0.
    let borderColors = [UIColor.systemGray2]
    //let borderColors = [UIColor.systemYellow, .systemRed, .systemOrange]
    
    // We are starting at the top center
    func pointOnCircle(radius: CGFloat, Θ: CGFloat, transform: CGFloat = 0) -> CGPoint {
        // Top center point (s,t) = (radius, 0)
        // (s,t) -> (u,v) = (s cos(Θ) + t sin(Θ), -s sin(Θ) + t cos(Θ))
        let s = radius
        let t = CGFloat.zero
        let u = s * cos(Θ) + t * sin(Θ)
        let v = -s * sin(Θ) + t * cos(Θ)
        return CGPoint(x: u + radius - 0.001 + transform, y: v + radius - 0.001 + transform)
    }

    // = length of hypotenuse
    func optimalDistance(n: Int) -> CGFloat {
        return (4/3) * tan(CGFloat.pi/(2 * CGFloat(n)))
    }
    
    func gradientTangent(point: CGPoint, center: CGPoint) -> CGFloat {
        return -1/((point.y - center.y)/(point.x - center.x))
    }
    
    func drawCircle(point: CGPoint, color: UIColor, radius: CGFloat = 2) {
        let circle = CGRect(x: point.x, y: point.y, width: radius * 2, height: radius * 2)
        let circlePath = CGPath(ellipseIn: circle, transform: nil)
        let layer = CAShapeLayer()
        layer.path = circlePath
        layer.fillColor = color.cgColor
        subView.layer.addSublayer(layer)
    }
    
    func drawLine(tangentPoint: CGPoint, slope: CGFloat, length: CGFloat = 300) {
        let path = UIBezierPath()
        let sideLength = length/2
        let origin = CGPoint(x: tangentPoint.x - sideLength, y: tangentPoint.y - sideLength * slope)
        path.move(to: origin)
        let destination = CGPoint(x: origin.x + length, y: origin.y + length * slope)
        path.addLine(to: destination)
        let layer = CAShapeLayer()
        layer.lineWidth = 1
        layer.strokeColor = UIColor.red.cgColor
        layer.path = path.cgPath
        subView.layer.addSublayer(layer)
    }
    
    func getPoint(slope: CGFloat, origin: CGPoint, distance: CGFloat, reverse: Bool) -> CGPoint {
        let α = atan(slope)
        
        let reverse = origin.y > radius ? !reverse : reverse
        
        let x = origin.x + (reverse ? -distance : distance) * cos(α)
        let y = origin.y + (reverse ? -distance : distance) * sin(α)
        
        return CGPoint(x: x, y: y)
    }
    
    override func loadView() {
        let view = UIView()
        containerView.backgroundColor = .white
        view.backgroundColor = .white
        view.addSubview(containerView)
        containerView.addSubview(subView)
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        containerView.addGestureRecognizer(tapGestureRecognizer)
        //panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        //containerView.addGestureRecognizer(panGestureRecognizer)
        
        (0...5).forEach { drawSegment(segment: $0, isChecked: isChecked) }
        
        self.view = view
    }
    
    func sigmoid(_ x: CGFloat) -> CGFloat {
        return 1/(1 + exp(-x))
    }
    
    @objc func tap(_ gestureRecognizer: UITapGestureRecognizer) {
        morph(isChecked: isChecked)
        isChecked = !isChecked
    }
    
    @objc func pan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let point = gestureRecognizer.translation(in: containerView)
        let centerX = containerView.bounds.midX
        let centerY = containerView.bounds.midY

        let height = containerView.frame.size.height
        let width = containerView.frame.size.width
        
        let deltaX = sigmoid((point.x - centerX)/width) * 2 - 0.5
        let deltaY = sigmoid((point.y - centerY)/height) * 2 - 0.5

        switch gestureRecognizer.state {
        case .began:
            break
        case .changed:
            let transform = CGAffineTransform(a: 1, b: deltaY * 0.05, c: deltaX * 0.05, d: 1, tx: 0, ty: 0)
            subView.transform = transform
        case .ended:
            UIView.animate(withDuration: 0.2) {
                self.subView.transform = .identity
            }
            
            morph(isChecked: !isChecked)
            isChecked = !isChecked
        default:
            break
        }
    }

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let xDist = a.x - b.x
        let yDist = a.y - b.y
        return CGFloat(sqrt(xDist * xDist + yDist * yDist))
    }
    
    func drawSegment(segment: Int, isChecked: Bool) {
        let distance = optimalDistance(n: numberOfSegments) * radius
        let innerDistance = optimalDistance(n: numberOfSegments) * (radius - borderWidth)
        let path = UIBezierPath()
        let nextSegment = (segment + 1) % numberOfSegments
        let innerRadius = radius - borderWidth
        let π = CGFloat.pi
        let startΘ = CGFloat(nextSegment) * CGFloat(2 * π)/CGFloat(numberOfSegments)
        let endΘ = CGFloat(segment) * CGFloat(2 * π)/CGFloat(numberOfSegments)
        let startOuterPoint = pointOnCircle(radius: radius, Θ: startΘ)
        path.move(to: startOuterPoint)
        let endOuterPoint = pointOnCircle(radius: radius, Θ: endΘ)
        
        let center = CGPoint(x: radius, y: radius)
        
        let slope = gradientTangent(point: startOuterPoint, center: center)
        let controlPoint1 = getPoint(slope: slope, origin: startOuterPoint, distance: distance, reverse: false)
        
        let slope2 = gradientTangent(point: endOuterPoint, center: center)
        let controlPoint2 = getPoint(slope: slope2, origin: endOuterPoint, distance: distance, reverse: true)

        path.addCurve(to: endOuterPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
        
        if !isChecked {
            let endInnerPoint = pointOnCircle(radius: innerRadius, Θ: endΘ, transform: borderWidth)
            path.addLine(to: endInnerPoint)

            let slope3 = gradientTangent(point: endInnerPoint, center: center)
            let controlPoint3 = getPoint(slope: slope3, origin: endInnerPoint, distance: innerDistance, reverse: true)
            
            let startInnerPoint = pointOnCircle(radius: innerRadius, Θ: startΘ, transform: borderWidth)
            let slope4 = gradientTangent(point: startInnerPoint, center: center)
            let controlPoint4 = getPoint(slope: slope4, origin: startInnerPoint, distance: innerDistance, reverse: false)
            
            path.addCurve(to: startInnerPoint, controlPoint1: controlPoint3, controlPoint2: controlPoint4)
            path.addLine(to: startOuterPoint)
        }
        else {
            // The checkmark dimensions are hardcoded, but grow with the checkbox's size.
            let gradient1: CGFloat = 0.6666666
            let gradient2: CGFloat = -1/gradient1
            
            let α = atan(gradient1)
            let γ = atan(gradient2)/2.5
            
            let thickness = 0.4 * radius
            let length = 1.2 * radius
            
            let p1 = CGPoint(x: radius * 1.5, y: radius * 0.65)
            
            let p2 = CGPoint(x: p1.x - thickness * α, y: p1.y - (thickness * α) * gradient1)
            let p3 = CGPoint(x: p2.x + length * γ, y: p2.y + length * γ * gradient2)
            let p4 = CGPoint(x: p3.x - thickness * α, y: p3.y - (thickness * α) * gradient1)
            let p5 = CGPoint(x: p4.x + thickness * γ, y: p4.y + (thickness * γ) * gradient2)
            let p6 = CGPoint(x: p5.x + thickness * 2 * α, y: p5.y + (thickness * 2 * α) * gradient1)
            let arr = [p1, p2, p3, p4, p5, p6]
            
            // Debug
            /*let colors = [UIColor.green, .cyan, .blue, .brown, .red, .purple]
            arr.enumerated().forEach { (i, point) in
                let color = colors[i]
                drawCircle(point: point, color: color)
            }*/
            
            let index1 = segment % numberOfSegments
            let point1 = arr[index1]
            let index2 = (segment + 1) % numberOfSegments
            let point2 = arr[index2]
            path.addLine(to: point1)
            path.addLine(to: point2)
        }

        path.close()

        if segmentLayers.count != numberOfSegments {
            let checkboxLayer = CAShapeLayer()
            segmentLayers.append(checkboxLayer)
            subView.layer.addSublayer(checkboxLayer)
        }
        
        let color = isChecked ? UIColor.systemGreen.cgColor : borderColors[Int(segment/(numberOfSegments/borderColors.count))].cgColor
        let index = segment % numberOfSegments
        let layer = segmentLayers[index]
        layer.fillColor = color
        layer.borderWidth = 0.2
        layer.strokeColor = color
        layer.path = path.cgPath
        
        // Debug
//        drawCircle(point: startOuterPoint, color: .blue)
//        drawCircle(point: endOuterPoint, color: .blue)
//        drawLine(tangentPoint: startOuterPoint, slope: slope)
//        drawLine(tangentPoint: endOuterPoint, slope: slope2)
//        drawCircle(point: controlPoint1, color: .gray)
//        drawCircle(point: controlPoint2, color: .gray)
        
//        drawCircle(point: startInnerPoint, color: .blue)
//        drawCircle(point: endInnerPoint, color: .blue)
//        drawLine(tangentPoint: endInnerPoint, slope: slope3)
//        drawLine(tangentPoint: startInnerPoint, slope: slope4)
//        drawCircle(point: controlPoint3, color: .red)
//        drawCircle(point: controlPoint4, color: .orange)
    }
    
    func morph(isChecked: Bool) {
        let animation = CABasicAnimation()
        animation.keyPath = "path"
        //animation.duration = 0.8
        //animation.timingFunction = CAMediaTimingFunction(controlPoints: 0, 1.9, 0.9, 0.9)
        animation.duration = 0.25
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.04, 0.17, 0.29, 0.95)
        animation.isRemovedOnCompletion = false
        for (i, layer) in segmentLayers.enumerated() {
            animation.fromValue = drawSegment(segment: i, isChecked: isChecked)
            animation.toValue = drawSegment(segment: i, isChecked: isChecked)
            layer.add(animation, forKey: "morph")
        }
        subView.setNeedsDisplay()
    }
}

// Present the view controller in the Live View window
PlaygroundPage.current.liveView = MyViewController()
