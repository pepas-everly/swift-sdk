//
//  Created by Tapash Majumder on 7/30/20.
//  Copyright © 2020 Iterable. All rights reserved.
//

import Foundation

struct IterableAPICallTaskProcessor: IterableTaskProcessor {
    let networkSession: NetworkSessionProtocol
    
    func process(task: IterableTask) throws -> Future<IterableTaskResult, IterableTaskError> {
        ITBInfo()
        guard let data = task.data else {
            return IterableTaskError.createErroredFuture(reason: "expecting data")
        }
        
        let iterableRequest = try JSONDecoder().decode(IterableAPICallRequest.self, from: data)
        guard let urlRequest = iterableRequest.convertToURLRequest() else {
            return IterableTaskError.createErroredFuture(reason: "could not convert to url request")
        }
        
        let result = Promise<IterableTaskResult, IterableTaskError>()
        NetworkHelper.sendRequest(urlRequest, usingSession: networkSession)
            .onSuccess { sendRequestValue in
                ITBInfo("Task finished successfully")
                result.resolve(with: .success(detail: sendRequestValue))
            }
            .onError { sendRequestError in
                if IterableAPICallTaskProcessor.isNetworkUnavailable(sendRequestError: sendRequestError) {
                    ITBInfo("Network is unavailable")
                    result.resolve(with: .failureWithRetry(retryAfter: nil, detail: sendRequestError))
                } else {
                    ITBInfo("Unrecoverable error")
                    result.resolve(with: .failureWithNoRetry(detail: sendRequestError))
                }
            }
        
        return result
    }
    
    private static func isNetworkUnavailable(sendRequestError: SendRequestError) -> Bool {
        if let originalError = sendRequestError.originalError {
            return originalError.localizedDescription.lowercased().contains("offline")
        } else {
            return false
        }
    }
}