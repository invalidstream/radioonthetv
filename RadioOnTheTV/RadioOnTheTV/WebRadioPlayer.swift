//
//  WebRadioPlayer.swift
//  RadioOnTheTV
//
//  Created by Chris Adamson on 3/6/16.
//  Copyright © 2016 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import AudioToolbox

enum PlayerState {
    case initialized
    case starting
    case playing
    case paused
    case error // todo: maybe an associated value with OSStatus?
}

extension PlayerState : CustomStringConvertible {
    var description : String {
        switch self {
        case .initialized: return "Initialized"
        case .starting: return "Starting"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .error: return "Error"
        }
    }
    
}

// this two-delegate stuff is really bad; maybe KVO on the state property would be better here
protocol PlayerInfoDelegate : class {
    func stateChangedForPlayerInfo(_ playerInfo: PlayerInfo)
}

class PlayerInfo {
    var dataFormat : AudioStreamBasicDescription?
    var audioQueue : AudioQueueRef?
    var totalPacketsReceived : UInt32 = 0
    var queueStarted : Bool = false
    weak var delegate : PlayerInfoDelegate?
    var state : PlayerState = .initialized {
        didSet {
            if state != oldValue {
                delegate?.stateChangedForPlayerInfo(self)
            }
        }
    }
}

/*
mime types in the wild:
MP3: audio/mpeg
AAC: application/octet-stream
*/

protocol WebRadioPlayerDelegate {
    func webRadioPlayerStateChanged(_ player : WebRadioPlayer)
}

class WebRadioPlayer : NSObject, URLSessionDataDelegate, PlayerInfoDelegate {
    
    fileprivate (set) var error : NSError?
    
    // TODO: figure out something nice with OSStatus
    // (to replace CheckError)
    
    fileprivate let stationURL : URL

    fileprivate var dataTask : URLSessionDataTask?
    
    // must be var of a class to do C-style pointer stuff
    var playerInfo : PlayerInfo
    
    var fileStream : AudioFileStreamID? = nil

    var delegate : WebRadioPlayerDelegate?
    
    var parseIsDiscontinuous = true
    
    init(stationURL : URL) {
        self.stationURL = stationURL
        playerInfo = PlayerInfo()
        super.init()
        playerInfo.delegate = self
        playerInfo.state = .initialized
    }
    
    func start() {
        playerInfo.state = .starting
        let urlSession = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        let dataTask = urlSession.dataTask(with: stationURL)
        self.dataTask = dataTask
        dataTask.resume()
    }

    func pause() {
        dataTask?.suspend()
        playerInfo.state = .paused
        if let audioQueue = playerInfo.audioQueue {
            let err = AudioQueueStop(audioQueue, true)
            if err != noErr {
                print("error happens when stop audio queue")
            }
        }
        parseIsDiscontinuous = true
    }

    func resume() {
        playerInfo.totalPacketsReceived = 0
        dataTask?.resume()
    }
    
    func stateChangedForPlayerInfo(_ playerInfo:PlayerInfo) {
        delegate?.webRadioPlayerStateChanged(self)
    }
    
    // MARK: - NSURLSessionDataDelegate
    func urlSession(_ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

            NSLog ("dataTask didReceiveResponse: \(response), MIME type \(response.mimeType)")
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    NSLog ("failed with response \(response)")
                    completionHandler(.cancel)
                    return
            }
            
            
            let streamTypeHint : AudioFileTypeID
            if let mimeType = response.mimeType {
                streamTypeHint = streamTypeHintForMIMEType(mimeType)
            } else {
                streamTypeHint = 0
            }
            
            var err = noErr
            err = AudioFileStreamOpen(&playerInfo,
                streamPropertyListenerProc,
                streamPacketsProc,
                streamTypeHint,
                &fileStream)
            NSLog ("created file stream, err = \(err)")
            
            completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data) {
            NSLog ("dataTask didReceiveData, \(data.count) bytes")
            
            var err = noErr
            let parseFlags : AudioFileStreamParseFlags
            if parseIsDiscontinuous {
                parseFlags = .discontinuity
                parseIsDiscontinuous = false
            } else {
                parseFlags = AudioFileStreamParseFlags()
            }
            err = AudioFileStreamParseBytes(fileStream!,
                UInt32(data.count),
                (data as NSData).bytes,
                parseFlags)
            
            NSLog ("wrote \(data.count) bytes to AudioFileStream, err = \(err)")
    }
    

    // MARK: - util
    fileprivate func streamTypeHintForMIMEType(_ mimeType : String) -> AudioFileTypeID {
        switch mimeType {
        case "audio/mpeg":
            return kAudioFileMP3Type
        case "application/octet-stream":
            return kAudioFileAAC_ADTSType
        default:
            return 0
        }
    }
    
}

// MARK: - AudioFileStream procs
// TODO: can these be private?
let streamPropertyListenerProc : AudioFileStream_PropertyListenerProc = {
    (inClientData : UnsafeMutableRawPointer,
    inAudioFileStreamID : AudioFileStreamID,
    inAudioFileStreamPropertyID : AudioFileStreamPropertyID,
    ioFlags : UnsafeMutablePointer<AudioFileStreamPropertyFlags>) -> Void in
    
//    let playerInfo = UnsafeMutablePointer<PlayerInfo>(inClientData).pointee
    let playerInfo = inClientData.assumingMemoryBound(to: PlayerInfo.self).pointee
    
    var err = noErr
    NSLog ("streamPropertyListenerProc, prop id \(inAudioFileStreamPropertyID)")
    
    switch inAudioFileStreamPropertyID {
    case kAudioFileStreamProperty_DataFormat:
        var dataFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        err = AudioFileStreamGetProperty(inAudioFileStreamID, inAudioFileStreamPropertyID,
            &propertySize, &dataFormat)
        NSLog ("got data format, err is \(err) \(dataFormat)")
        playerInfo.dataFormat = dataFormat
        NSLog ("playerInfo.dataFormat: \(playerInfo.dataFormat)")
    case kAudioFileStreamProperty_MagicCookieData:
        NSLog ("got magic cookie")
    case kAudioFileStreamProperty_ReadyToProducePackets:
        NSLog ("got ready to produce packets")
        var audioQueue: AudioQueueRef? = nil
        var dataFormat = playerInfo.dataFormat!
        err = AudioQueueNewOutput(&dataFormat,
            queueCallbackProc,
            inClientData,
            nil,
            nil,
            0,
            &audioQueue)
        NSLog ("created audio queue, err is \(err), queue is \(audioQueue)")
        playerInfo.audioQueue = audioQueue
    default:
        break
        
    }
    
}

let streamPacketsProc : AudioFileStream_PacketsProc = {
    (inClientData : UnsafeMutableRawPointer,
    inNumberBytes : UInt32,
    inNumberPackets : UInt32,
    inInputData : UnsafeRawPointer,
    inPacketDescriptions : UnsafeMutablePointer<AudioStreamPacketDescription>) -> Void in
    
    var err = noErr
    NSLog ("streamPacketsProc got \(inNumberPackets) packets")
//    let playerInfo = UnsafeMutablePointer<PlayerInfo>(inClientData).pointee
    let playerInfo = inClientData.assumingMemoryBound(to: PlayerInfo.self).pointee
    var buffer: AudioQueueBufferRef? = nil
    if let audioQueue = playerInfo.audioQueue {
        err = AudioQueueAllocateBuffer(audioQueue,
            inNumberBytes,
            &buffer)
        NSLog ("allocated buffer, err is \(err) buffer is \(buffer)")
        buffer?.pointee.mAudioDataByteSize = inNumberBytes
        memcpy(buffer?.pointee.mAudioData, inInputData, Int(inNumberBytes))
        NSLog ("copied data, not dead yet")
        
        err = AudioQueueEnqueueBuffer(audioQueue,
            buffer!,
            inNumberPackets,
            inPacketDescriptions)
        NSLog ("enqueued buffer, err is \(err)")
        
        playerInfo.totalPacketsReceived += inNumberPackets
        if playerInfo.totalPacketsReceived > 100 {
            err = AudioQueueStart (audioQueue,
                nil)
            NSLog ("started playing, err is \(err)")
            playerInfo.state = .playing
        }
    }
}

// MARK: - AudioQueue callback
let queueCallbackProc : AudioQueueOutputCallback = { (inUserData, inAudioQueue, inQueueBuffer) in
    NSLog ("queueCallbackProc")
    var err = noErr
    err = AudioQueueFreeBuffer (inAudioQueue, inQueueBuffer)
    NSLog ("freed a buffer, err is \(err)")
}
