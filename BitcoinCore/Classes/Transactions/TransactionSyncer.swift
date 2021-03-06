import Foundation

public class TransactionSyncer {
    private let storage: IStorage
    private let transactionProcessor: ITransactionProcessor
    private let publicKeyManager: IPublicKeyManager

    init(storage: IStorage, processor: ITransactionProcessor, publicKeyManager: IPublicKeyManager) {
        self.storage = storage
        self.transactionProcessor = processor
        self.publicKeyManager = publicKeyManager
    }

}

extension TransactionSyncer: ITransactionSyncer {

    public func newTransactions() -> [FullTransaction] {
        storage.newTransactions().map {
            FullTransaction(
                    header: $0,
                    inputs: self.storage.inputs(transactionHash: $0.dataHash),
                    outputs: self.storage.outputs(transactionHash: $0.dataHash)
            )
        }
    }

    public func handleRelayed(transactions: [FullTransaction]) {
        guard !transactions.isEmpty else {
            return
        }

        var needToUpdateBloomFilter = false

        do {
            try self.transactionProcessor.processReceived(transactions: transactions, inBlock: nil, skipCheckBloomFilter: false)
        } catch _ as BloomFilterManager.BloomFilterExpired {
            needToUpdateBloomFilter = true
        } catch {
        }

        if needToUpdateBloomFilter {
            try? publicKeyManager.fillGap()
        }
    }

    public func handleInvalid(fullTransaction: FullTransaction) {
        transactionProcessor.processInvalid(transactionHash: fullTransaction.header.dataHash, conflictingTxHash: nil)
    }

    public func shouldRequestTransaction(hash: Data) -> Bool {
        !storage.relayedTransactionExists(byHash: hash)
    }

}
