// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum State {
        Pending,
        Approved,
        Rejected
    }

struct Signer {
        address account;
        State state;
        uint256 signedAt;
    }


library SignerArray{
    function find(Signer[] storage _signer, address addr) internal view returns (int){
        for (uint i; i < _signer.length ; i++){
            if (_signer[i].account == addr){
                return int(i);
            }

        }
        return -1;
    }
}
//0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
//0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
contract MultiSign{
    using SignerArray for Signer[];

   
    
    struct Transaction {
        uint256 id;
        string title;
        address to;
        uint256 value;
        bytes data;
        State state;
      
        uint256[3] timeAt;//approvedAt,rejectedAt,createdAt
    }
    address[] public owner;
    uint256 public txId;
    mapping (uint256 => Signer[]) public  transactionSigner; 
    Transaction[] transaction;

    event Commited(uint256 indexed txId, address indexed creator, string  title, uint256 timeAt);
    event Approved(uint256 indexed txId, address indexed signer, uint256 timeAt);
    event Rejected(uint256 indexed txId, address indexed signer, uint256 timeAt);
     receive() external payable { }
    fallback() external payable { }

    constructor(address[] memory _owner){
        owner = _owner;
    }
    modifier onlyOwner(){
        bool exsit;
        for (uint256 i; i < owner.length; i++){
            if (owner[i] == msg.sender){
                exsit = true;
                break ;
            }
        }
        require(exsit, "Permission denied");
        _;
    }

    function commit(string memory title, address to,uint256 value, bytes calldata data)  external onlyOwner{
        Transaction memory trx;
        trx.id = ++txId;
        trx.title = title;
        trx.to = to;
        trx.value = value;
        trx.data = data;
        trx.state = State.Pending;
        trx.timeAt[2] = block.timestamp;
        transaction.push(trx);

        transactionSigner[txId].push(Signer({
            account: msg.sender, 
            state: State.Approved, 
            signedAt: block.timestamp
            }));
        emit Commited(trx.id, msg.sender, trx.title, block.timestamp);

    }

    modifier checkBefore(uint256 _txId){
        require(_txId > 0 && _txId <= txId, "Trx does not exists");
        require(transaction[_txId - 1].state == State.Pending,"Trx was finished");

        require(transactionSigner[_txId].find(msg.sender) == -1, "Trx was signed");
        _;
    }
    function approved(uint256 _txId) external onlyOwner checkBefore(_txId){
        
        transactionSigner[_txId].push(Signer({
            account: msg.sender,
            state: State.Approved,
            signedAt: block.timestamp
        }));
       
        if(transactionSigner[_txId].length == owner.length){
        
        transaction[_txId - 1].state = State.Approved;
        transaction[_txId - 1].timeAt[0] = block.timestamp;

        Transaction memory trx = transaction[_txId - 1];
        (bool ok, ) = address(trx.to).call{ value: trx.value }(trx.data);
        require(ok, "Execute failed");
        }
        
        emit Approved(_txId, msg.sender, block.timestamp);

    }

    function rejected(uint256 _txId) external onlyOwner checkBefore(_txId){

        transaction[_txId - 1].state = State.Rejected;
         transaction[_txId - 1].timeAt[1] = block.timestamp;
         transactionSigner[_txId].push(Signer({
            account: msg.sender,
            state: State.Rejected,
            signedAt: block.timestamp
        }));
         emit Approved(_txId, msg.sender, block.timestamp);

    }

 function getTransactionList(
        State state,
        uint256 pageNum,
        uint256 pageSize)
        external view returns (Transaction[] memory){
            
            Transaction[] memory result = new Transaction[](pageSize);
            uint256 offset = pageNum <= 1 ? 0 : (pageNum - 1) * pageSize;

            uint256 count;
            for (uint256 n = offset; n < transaction.length && count < pageSize; n++){
                if (transaction[n].state == state){
                    result[count++] = transaction[n];
                }
            }
            
            Transaction[] memory resultFilter = new Transaction[](count);
            for (uint256 j = 0; j < count; j++) {
                resultFilter[j] = result[j];
            }
            return resultFilter;
        }


    

}


