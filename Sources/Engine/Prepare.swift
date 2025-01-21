//
//  Prepare.swift
//

import AST
import Foundation
import IR

//struct VMEvaluationContext {
//    let Policies: [IR.Policy]
//}
//
//// Prepare bundles for evaluation
//func prepare( bundles: [Bundle], store: inout Store) throws -> VMEvaluationContext {
//    var policies: [IR.Policy] = []
//
//    for bundle in bundles {
//        for pf in bundle.planFiles {
//            let policy = try IR.Policy(fromJson: pf.data)
//            policies.append(policy) // TODO - do we need to keep track of which bundle a policy came from?
//        }
//
//        // Load data
//        //let roots = bundle.manifest.roots
//    }
//
//    return VMEvaluationContext(Policies: policies)
//}
