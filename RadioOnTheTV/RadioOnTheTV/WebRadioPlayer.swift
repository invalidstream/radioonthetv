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
    case Initialized
    case Starting
    case Playing
    case Paused
    case Error // todo: maybe an associated value with OSStatus?
}

extension PlayerState : CustomStringConvertible {
    var description : String {
        switch self {
        case .Initialized: return "Initialized"
        case .Starting: return "Starting"
        case .Playing: return "Playing"
        case .Paused: return "Paused"
        case .Error: return "Error"
        }
    }
    
}

// this two-delegate stuff is really bad; maybe KVO on the state property would be better here
protocol PlayerInfoDelegate : class {
    func stateChangedForPlayerInfo(playerInfo: PlayerInfo)
}

class PlayerInfo {
    var dataFormat : AudioStreamBasicDescription?
    var audioQueue : AudioQueueRef?
    var totalPacketsReceived : UInt32 = 0
    var queueStarted : Bool = false
    weak var delegate : PlayerInfoDelegate?
    var state : PlayerState = .Initialized {
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
    func webRadioPlayerStateChanged(player : WebRadioPlayer)
}

class WebRadioPlayer : NSObject, NSURLSessionDataDelegate, PlayerInfoDelegate {
    
    private (set) var error : NSError?
    
    // TODO: figure out something nice with OSStatus
    // (to replace CheckError)
    
    private let stationURL : NSURL

    private var dataTask : NSURLSessionDataTask?
    
    // must be var of a class to do C-style pointer stuff
    var playerInfo : PlayerInfo
    
    var fileStream : AudioFileStreamID = AudioFileStreamID()

    var delegate : WebRadioPlayerDelegate?
    
    var parseIsDiscontinuous = true
    
    init(stationURL : NSURL) {
        self.stationURL = stationURL
        playerInfo = PlayerInfo()
        super.init()
        playerInfo.delegate = self
        playerInfo.state = .Initialized
    }
    
    func start() {
        playerInfo.state = .Starting
        let urlSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: nil)
        let dataTask = urlSession.dataTaskWithURL(stationURL)
        self.dataTask = dataTask
        dataTask.resume()
    }

    func pause() {
        dataTask?.suspend()
        playerInfo.state = .Paused
        if let audioQueue = playerInfo.audioQueue {
            var err = noErr
            err = AudioQueueStop(audioQueue, true)
        }
        parseIsDiscontinuous = true
    }

    func resume() {
        playerInfo.totalPacketsReceived = 0
        dataTask?.resume()
    }
    
    func stateChangedForPlayerInfo(playerInfo:PlayerInfo) {
        delegate?.webRadioPlayerStateChanged(self)
    }
    
    // MARK: - NSURLSessionDataDelegate
    func URLSession(session: NSURLSession,
        dataTask: NSURLSessionDataTask,
        didReceiveResponse response: NSURLResponse,
        completionHandler: (NSURLSessionResponseDisposition) -> Void) {

            NSLog ("dataTask didReceiveResponse: \(response), MIME type \(response.MIMEType)")
            
            guard let httpResponse = response as? NSHTTPURLResponse
                where httpResponse.statusCode == 200 else {
                    NSLog ("failed with response \(response)")
                    completionHandler(.Cancel)
                    return
            }
            
            
            let streamTypeHint : AudioFileTypeID
            if let mimeType = response.MIMEType {
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
            
            completionHandler(.Allow)
    }
    
    func URLSession(session: NSURLSession,
        dataTask: NSURLSessionDataTask,
        didReceiveData data: NSData) {
            NSLog ("dataTask didReceiveData, \(data.length) bytes")
            
            var err = noErr
            let parseFlags : AudioFileStreamParseFlags
            if parseIsDiscontinuous {
                parseFlags = .Discontinuity
                parseIsDiscontinuous = false
            } else {
                parseFlags = AudioFileStreamParseFlags()
            }
            err = AudioFileStreamParseBytes(fileStream,
                UInt32(data.length),
                data.bytes,
                parseFlags)
            
            NSLog ("wrote \(data.length) bytes to AudioFileStream, err = \(err)")
    }
    

    // MARK: - util
    private func streamTypeHintForMIMEType(mimeType : String) -> AudioFileTypeID {
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
    (inClientData : UnsafeMutablePointer<Void>,
    inAudioFileStreamID : AudioFileStreamID,
    inAudioFileStreamPropertyID : AudioFileStreamPropertyID,
    ioFlags : UnsafeMutablePointer<AudioFileStreamPropertyFlags>) -> Void in
    
    let playerInfo = UnsafeMutablePointer<PlayerInfo>(inClientData).memory
    var err = noErr
    NSLog ("streamPropertyListenerProc, prop id \(inAudioFileStreamPropertyID)")
    
    switch inAudioFileStreamPropertyID {
    case kAudioFileStreamProperty_DataFormat:
        var dataFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(sizeof(AudioStreamBasicDescription))
        err = AudioFileStreamGetProperty(inAudioFileStreamID, inAudioFileStreamPropertyID,
            &propertySize, &dataFormat)
        NSLog ("got data format, err is \(err) \(dataFormat)")
        playerInfo.dataFormat = dataFormat
        NSLog ("playerInfo.dataFormat: \(playerInfo.dataFormat)")
    case kAudioFileStreamProperty_MagicCookieData:
        NSLog ("got magic cookie")
    case kAudioFileStreamProperty_ReadyToProducePackets:
        NSLog ("got ready to produce packets")
        var audioQueue = AudioQueueRef()
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
    (inClientData : UnsafeMutablePointer<Void>,
    inNumberBytes : UInt32,
    inNumberPackets : UInt32,
    inInputData : UnsafePointer<Void>,
    inPacketDescriptions : UnsafeMutablePointer<AudioStreamPacketDescription>) -> Void in
    
    var err = noErr
    NSLog ("streamPacketsProc got \(inNumberPackets) packets")
    let playerInfo = UnsafeMutablePointer<PlayerInfo>(inClientData).memory
    
    var buffer = AudioQueueBufferRef()
    if let audioQueue = playerInfo.audioQueue {
        err = AudioQueueAllocateBuffer(audioQueue,
            inNumberBytes,
            &buffer)
        NSLog ("allocated buffer, err is \(err) buffer is \(buffer)")
        buffer.memory.mAudioDataByteSize = inNumberBytes
        memcpy(buffer.memory.mAudioData, inInputData, Int(inNumberBytes))
        NSLog ("copied data, not dead yet")
        
        err = AudioQueueEnqueueBuffer(audioQueue,
            buffer,
            inNumberPackets,
            inPacketDescriptions)
        NSLog ("enqueued buffer, err is \(err)")
        
        playerInfo.totalPacketsReceived += inNumberPackets
        if playerInfo.totalPacketsReceived > 100 {
            err = AudioQueueStart (audioQueue,
                nil)
            NSLog ("started playing, err is \(err)")
            playerInfo.state = .Playing
        }
    }
}

// MARK: - AudioQueue callback
let queueCallbackProc : AudioQueueOutputCallback = {
    (inUserData : UnsafeMutablePointer<Void>,
    inAudioQueue : AudioQueueRef,
    inQueueBuffer : AudioQueueBufferRef) -> Void in
    NSLog ("queueCallbackProc")
    let playerInfo = UnsafeMutablePointer<PlayerInfo>(inUserData).memory
    var err = noErr
    err = AudioQueueFreeBuffer (inAudioQueue, inQueueBuffer)
    NSLog ("freed a buffer, err is \(err)")
}
