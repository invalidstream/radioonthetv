//
//  WebRadioPlayer.swift
//  RadioOnTheTV
//
//  Created by Chris Adamson on 3/6/16.
//  Copyright © 2016 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import AudioToolbox

class PlayerState {
    var dataFormat : AudioStreamBasicDescription?
    var audioQueue : AudioQueueRef?
    var totalPacketsReceived : UInt32 = 0
    var queueStarted : Bool = false
}

/*
mime types in the wild:
MP3: audio/mpeg
AAC: application/octet-stream
*/

class WebRadioPlayer : NSObject, NSURLSessionDataDelegate {
    
    // TODO: figure out something nice with OSStatus
    // (to replace CheckError)
    
    private let stationURL : NSURL

    // must be var of a class to do C-style pointer stuff
    var playerState = PlayerState()
    
    var fileStream : AudioFileStreamID = AudioFileStreamID()

    
    init(stationURL : NSURL) {
        self.stationURL = stationURL
    }
    
    func start() {
        let urlSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: nil)
        let dataTask = urlSession.dataTaskWithURL(stationURL)
        dataTask.resume()
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
            err = AudioFileStreamOpen(&playerState,
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
            err = AudioFileStreamParseBytes(fileStream,
                UInt32(data.length),
                data.bytes,
                AudioFileStreamParseFlags())
            
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
let streamPropertyListenerProc : AudioFileStream_PropertyListenerProc = {
    (inClientData : UnsafeMutablePointer<Void>,
    inAudioFileStreamID : AudioFileStreamID,
    inAudioFileStreamPropertyID : AudioFileStreamPropertyID,
    ioFlags : UnsafeMutablePointer<AudioFileStreamPropertyFlags>) -> Void in
    
    let playerState = UnsafeMutablePointer<PlayerState>(inClientData).memory
    var err = noErr
    NSLog ("streamPropertyListenerProc, prop id \(inAudioFileStreamPropertyID)")
    
    switch inAudioFileStreamPropertyID {
    case kAudioFileStreamProperty_DataFormat:
        var dataFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(sizeof(AudioStreamBasicDescription))
        err = AudioFileStreamGetProperty(inAudioFileStreamID, inAudioFileStreamPropertyID,
            &propertySize, &dataFormat)
        NSLog ("got data format, err is \(err) \(dataFormat)")
        playerState.dataFormat = dataFormat
        NSLog ("playerState.dataFormat: \(playerState.dataFormat)")
    case kAudioFileStreamProperty_MagicCookieData:
        NSLog ("got magic cookie")
    case kAudioFileStreamProperty_ReadyToProducePackets:
        NSLog ("got ready to produce packets")
        var audioQueue = AudioQueueRef()
        var dataFormat = playerState.dataFormat!
        err = AudioQueueNewOutput(&dataFormat,
            queueCallbackProc,
            inClientData,
            nil,
            nil,
            0,
            &audioQueue)
        NSLog ("created audio queue, err is \(err), queue is \(audioQueue)")
        playerState.audioQueue = audioQueue
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
    let playerState = UnsafeMutablePointer<PlayerState>(inClientData).memory
    
    var buffer = AudioQueueBufferRef()
    if let audioQueue = playerState.audioQueue {
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
        
        playerState.totalPacketsReceived += inNumberPackets
        if playerState.totalPacketsReceived > 100 {
            err = AudioQueueStart (audioQueue,
                nil)
            NSLog ("started playing, err is \(err)")
        }
    }
}

// MARK: - AudioQueue callback
let queueCallbackProc : AudioQueueOutputCallback = {
    (inUserData : UnsafeMutablePointer<Void>,
    inAudioQueue : AudioQueueRef,
    inQueueBuffer : AudioQueueBufferRef) -> Void in
    NSLog ("queueCallbackProc")
    let playerState = UnsafeMutablePointer<PlayerState>(inUserData).memory
    var err = noErr
    err = AudioQueueFreeBuffer (inAudioQueue, inQueueBuffer)
    NSLog ("freed a buffer, err is \(err)")
}
