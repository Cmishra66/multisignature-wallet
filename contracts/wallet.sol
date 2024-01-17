// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSignatureWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) approvals;
        uint256 approvalCount;
    }

    Transaction[] public transactions;

    event OwnershipAdded(address newOwner);
    event OwnershipRemoved(address removedOwner);
    event TransactionSubmitted(uint256 transactionId, address to, uint256 value, bytes data);
    event TransactionApproved(uint256 transactionId, address approver);
    event TransactionExecuted(uint256 transactionId, address executor);
    event TransactionCancelled(uint256 transactionId);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    modifier notApproved(uint256 transactionId) {
        require(!transactions[transactionId].approvals[msg.sender], "Transaction already approved by this owner");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0 && _threshold > 0 && _threshold <= _owners.length, "Invalid parameters");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0) && !isOwner[owner], "Invalid owner");
            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    function addOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0) && !isOwner[newOwner], "Invalid owner");
        isOwner[newOwner] = true;
        owners.push(newOwner);
        emit OwnershipAdded(newOwner);
    }

    function removeOwner(address ownerToRemove) external onlyOwner {
        require(isOwner[ownerToRemove], "Not an owner");
        require(owners.length > 1, "Cannot remove the last owner");
        isOwner[ownerToRemove] = false;

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == ownerToRemove) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                emit OwnershipRemoved(ownerToRemove);
                break;
            }
        }
    }

   function submitTransaction(address to, uint256 value, bytes memory data) external onlyOwner {
    uint256 transactionId = transactions.length;
    transactions.push();
    Transaction storage newTransaction = transactions[transactionId];
    
    newTransaction.to = to;
    newTransaction.value = value;
    newTransaction.data = data;
    newTransaction.executed = false;
    newTransaction.approvalCount = 0;

    emit TransactionSubmitted(transactionId, to, value, data);
}


    function approveTransaction(uint256 transactionId) external onlyOwner transactionExists(transactionId) notExecuted(transactionId) notApproved(transactionId) {
        transactions[transactionId].approvals[msg.sender] = true;
        transactions[transactionId].approvalCount++;

        emit TransactionApproved(transactionId, msg.sender);

        if (transactions[transactionId].approvalCount >= threshold) {
            executeTransaction(transactionId);
        }
    }

    function cancelTransaction(uint256 transactionId) external onlyOwner transactionExists(transactionId) notExecuted(transactionId) {
        transactions[transactionId].executed = true;
        emit TransactionCancelled(transactionId);
    }

    function executeTransaction(uint256 transactionId) internal transactionExists(transactionId) notExecuted(transactionId) {
        transactions[transactionId].executed = true;

        (bool success, ) = transactions[transactionId].to.call{value: transactions[transactionId].value}(transactions[transactionId].data);
        require(success, "Transaction execution failed");

        emit TransactionExecuted(transactionId, msg.sender);
    }
}
