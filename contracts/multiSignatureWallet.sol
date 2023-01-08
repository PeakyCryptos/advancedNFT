pragma solidity 0.8.17;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed signer, uint256 indexed txId);
    event Revoke(address indexed signer, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool complete;
    }

    address[] public signers;
    mapping(address => bool) public isSigner;
    uint256 public minSigners; // amt of signatures needed to sign a transaction

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;

    constructor(address[] memory _signers, uint256 _minSigners) {
        require(_signers.length > 0, "No signers specified!");
        require(
            _minSigners > 0 && _minSigners <= _signers.length,
            "Invalid number of signers specified!"
        );

        for (uint256 i; i < _signers.length; ++i) {
            address signer = _signers[i];

            require(signer != address(0), "Invalid signer!");
            require(!isSigner[signer], "Duplicate signer!");

            isSigner[signer] = true;
            signers.push(signer);
        }

        minSigners = _minSigners;
    }

    modifier onlySigner() {
        require(isSigner[msg.sender], "Not a valid signer!");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "Invalid transaction specified!");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(
            !approved[_txId][msg.sender],
            "You have already approved this transaction!"
        );
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].complete, "transaction already executed!");
        _;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlySigner {
        transactions.push(
            Transaction({to: _to, value: _value, data: _data, complete: false})
        );
        emit Submit(transactions.length - 1);
    }

    function approve(uint256 _txId)
        external
        onlySigner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint256 _txId)
        internal
        view
        returns (uint256 count)
    {
        for (uint256 i; i < signers.length; ++i) {
            if (approved[_txId][signers[i]]) {
                count += 1;
            }
        }
        return count;
    }

    function execute(uint256 _txId)
        external
        txExists(_txId)
        notExecuted(_txId)
    {
        require(
            minSigners <= _getApprovalCount(_txId),
            "Not enough approvals!"
        );
        Transaction storage transaction = transactions[_txId];

        transaction.complete = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed!");

        emit Execute(_txId);
    }

    function revoke(uint256 _txId)
        external
        onlySigner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(
            approved[_txId][msg.sender],
            "Transaction already not approved!"
        );
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}
