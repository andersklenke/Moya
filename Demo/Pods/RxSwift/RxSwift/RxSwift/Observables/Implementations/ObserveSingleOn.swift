//
//  ObserveSingleOn.swift
//  Rx
//
//  Created by Krunoslav Zaher on 3/15/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

// This class is used to forward sequence of AT MOST ONE observed element to
// another schedule.
//
// In case sequence contains more then one element, it will fire an exception.

class ObserveSingleOnObserver<O: ObserverType> : Sink<O>, ObserverType, Disposable {
    typealias Element = O.Element
    typealias Parent = ObserveSingleOn<Element>
    
    let parent: Parent
   
    var lastElement: Event<Element>? = nil
    
    init(parent: Parent, observer: O, cancel: Disposable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
 
    func on(event: Event<Element>) {
        var elementToForward: Event<Element>?
        var stopEventToForward: Event<Element>?
        
        let scheduler = self.parent.scheduler
        
        switch event {
        case .Next:
            if self.lastElement != nil {
                rxFatalError("Sequence contains more then one element")
            }
            
            self.lastElement = event
        case .Error:
            if self.lastElement != nil {
                rxFatalError("Observed sequence was expected to have more then one element")
            }
            stopEventToForward = event
        case .Completed:
            elementToForward = self.lastElement
            stopEventToForward = event
        }
        
        if let stopEventToForward = stopEventToForward {
            self.parent.scheduler.schedule(()) { (_) in
                if let elementToForward = elementToForward {
                    trySend(self.observer, elementToForward)
                }
                
                trySend(self.observer, stopEventToForward)
                
                self.dispose()
                
                return SuccessResult
            }
        }
    }

    func run() -> Disposable {
        return self.parent.source.subscribe(self)
    }
}

class ObserveSingleOn<Element> : Producer<Element> {
    let scheduler: ImmediateScheduler
    let source: Observable<Element>
    
    init(source: Observable<Element>, scheduler: ImmediateScheduler) {
        self.source = source
        self.scheduler = scheduler
    }
    
    override func run<O: ObserverType where O.Element == Element>(observer: O, cancel: Disposable, setSink: (Disposable) -> Void) -> Disposable {
        let sink = ObserveSingleOnObserver(parent: self, observer: observer, cancel: cancel)
        setSink(sink)
        return sink.run()
    }
}