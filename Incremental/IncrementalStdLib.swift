//
//  IncrementalStdLib.swift
//  IncrementalCLI
//
//  Created by Chris Eidhof on 19.08.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

public func if_<A: Equatable>(_ cond: I<Bool>, _ then: @autoclosure @escaping () -> I<A>, else alt:  @autoclosure @escaping () -> I<A>) -> I<A> {
    return cond.flatMap { $0 ? then() : alt() }
}
