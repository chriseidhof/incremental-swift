//
//  AppDelegate.swift
//  IncrementalFilesystem
//
//  Created by Chris Eidhof on 02.08.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Cocoa
import Incremental
import CoreServices

final class DirectoryObserver {
    var stream: FSEventStreamRef! = nil
    let runloop: CFRunLoop!
    
    init?(paths: [String], observer: () -> ()) {
        runloop = CFRunLoopGetCurrent()
        var streamContext = FSEventStreamContext(version: 0, info: Unmanaged.passRetained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = {
            (ref: ConstFSEventStreamRef, clientInfo: UnsafeMutableRawPointer?, numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIds: UnsafePointer<FSEventStreamEventId>) in
            let paths = Unmanaged<NSArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            dump(eventFlags.pointee)
            print(numEvents)
            //  as! [String]
            print("callback! \(paths)")
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagIgnoreSelf
            | kFSEventStreamCreateFlagFileEvents)
        guard let stream = FSEventStreamCreate(nil, callback, &streamContext, paths.map { $0 as CFString } as CFArray, UInt64(kFSEventStreamEventIdSinceNow), 1, flags) else { return nil }
        FSEventStreamScheduleWithRunLoop(stream, runloop, CFRunLoopMode.defaultMode.rawValue)
        self.stream = stream
        FSEventStreamStart(stream)

    }
    
    deinit {
        FSEventStreamStop(stream)
        FSEventStreamUnscheduleFromRunLoop(stream, runloop, CFRunLoopMode.defaultMode.rawValue)
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var observer: DirectoryObserver?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        observer = DirectoryObserver(paths: ["/Users/chris/Desktop/Incremental/sample"]) {
            print("event")
        }
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

func callback(ref: ConstFSEventStreamRef, p: UnsafeMutableRawPointer?, numEvents: Int, eventPaths:  UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIds: UnsafePointer<FSEventStreamEventId>) {
    print((ref, numEvents))
}
