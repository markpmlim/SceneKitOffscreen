//
//  AppDelegate.swift
//  SceneKitDelegate
//
//  Created by mark lim pak mun on 19/04/2019.
//  Copyright © 2019 Incremental Innovation. All rights reserved.
//

import Cocoa
import OpenGL.GL3

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        var rawPointer = UnsafeRawPointer(glGetString(GLenum(GL_RENDERER)))!
        let rendererStr = String(cString: rawPointer.assumingMemoryBound(to: CChar.self))
        print(rendererStr)
        rawPointer = UnsafeRawPointer(glGetString(GLenum(GL_VERSION)))!
        let versionStr = String(cString: rawPointer.assumingMemoryBound(to: CChar.self))
        print(versionStr)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

