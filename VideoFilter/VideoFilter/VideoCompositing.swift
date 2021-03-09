//
//  VideoCompositing.swift
//  VideoFilter
//
//  Created by MAC on 2021/3/8.
//

import UIKit
import AVFoundation

/// Errors that can be thrown from VideoCompositor
enum VideoCompositorError: Error {
    case missingTrack
    case missingSourceFrame
    case missingSampleBuffer
}

class VideoCompositing: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String: Any]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }

    private var shouldCancelAllRequests = false
    private var internalRenderContextDidChange = false
    private var firstFrame = true

    private let renderingQueue: DispatchQueue
    private let renderContextQueue: DispatchQueue
    private var renderContext: AVVideoCompositionRenderContext?
    private var asyncVideoCompositionRequests: [AVAsynchronousVideoCompositionRequest] = []

    private var renderContextDidChange: Bool {
        get {
            return renderContextQueue.sync { internalRenderContextDidChange }
        }
        set (newRenderContextDidChange) {
            renderContextQueue.sync { internalRenderContextDidChange = newRenderContextDidChange }
        }
    }

    var startTime: CMTime?

    var dimensions: CGSize = .zero

    /// Convenience initializer
    override convenience init() {
        self.init(
            renderingQueue: DispatchQueue(label: "kanvas.videocompositor.renderingqueue"),
            renderContextQueue: DispatchQueue(label: "kanvas.videocompositor.rendercontextqueue")
        )
    }

    /// Designated initializer
    init(renderingQueue: DispatchQueue, renderContextQueue: DispatchQueue) {
        self.renderingQueue = renderingQueue
        self.renderContextQueue = renderContextQueue
        super.init()
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContextQueue.sync { renderContext = newRenderContext }
        renderContextDidChange = true
    }

    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        renderingQueue.async {
            if self.shouldCancelAllRequests {
                asyncVideoCompositionRequest.finishCancelledRequest()
            }
            else {
                guard let trackID = asyncVideoCompositionRequest.sourceTrackIDs.first else {
                    asyncVideoCompositionRequest.finish(with: VideoCompositorError.missingTrack)
                    return
                }
                guard let sourcePixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: trackID.int32Value) else {
                    asyncVideoCompositionRequest.finish(with: VideoCompositorError.missingSourceFrame)
                    return
                }

                if self.renderContextDidChange {
                    self.renderContextDidChange = false
                }

                guard let sampleBuffer = sourcePixelBuffer.sampleBuffer() else {
                    asyncVideoCompositionRequest.finish(with: VideoCompositorError.missingSampleBuffer)
                    return
                }

                self.asyncVideoCompositionRequests.insert(asyncVideoCompositionRequest, at: 0)

                if self.firstFrame {
                    self.startTime = asyncVideoCompositionRequest.compositionTime
                    self.renderer.processSampleBuffer(sampleBuffer, time: 0)
                    self.firstFrame = false
                }
                self.renderer.processSampleBuffer(sampleBuffer, time: asyncVideoCompositionRequest.compositionTime.seconds - (self.startTime?.seconds ?? 0))
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        renderingQueue.sync {
            shouldCancelAllRequests = true
        }
        renderingQueue.async {
            self.shouldCancelAllRequests = false
        }
    }
    
    func newRenderdPixelBufferForRequest(asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer {
        
    }

//    - (CVPixelBufferRef)newRenderdPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request {
//        CustomVideoCompositionInstruction *videoCompositionInstruction = (CustomVideoCompositionInstruction *)request.videoCompositionInstruction;
//        NSArray<AVVideoCompositionLayerInstruction *> *layerInstructions = videoCompositionInstruction.layerInstructions;
//        CMPersistentTrackID trackID = layerInstructions.firstObject.trackID;
//
//        CVPixelBufferRef sourcePixelBuffer = [request sourceFrameByTrackID:trackID];
//        CVPixelBufferRef resultPixelBuffer = [videoCompositionInstruction applyPixelBuffer:sourcePixelBuffer];
//
//        if (!resultPixelBuffer) {
//            CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
//            return emptyPixelBuffer;
//        } else {
//            return resultPixelBuffer;
//        }
//    }
//
//    /// 创建一个空白的视频帧
//    - (CVPixelBufferRef)createEmptyPixelBuffer {
//        CVPixelBufferRef pixelBuffer = [self.renderContext newPixelBuffer];
//        CIImage *image = [CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0 alpha:0]];
//        [self.ciContext render:image toCVPixelBuffer:pixelBuffer];
//        return pixelBuffer;
//    }

}

