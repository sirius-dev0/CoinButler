// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./cstLockable.sol";
 
contract cst is ERC20, Ownable, LockToken {
    using SafeMath for uint256;

    uint8 public _decimals = 18;
    uint256 public initialSupply = 1000000000 * (10 ** uint256(_decimals));

    mapping(address => uint256) internal balances;

    string internal constant INVALID_TOKEN_VALUES = 'Invalid token values';
	string internal constant NOT_ENOUGH_TOKENS = 'Not enough tokens';
    string internal constant ALREADY_LOCKED = 'Tokens already locked';
	string internal constant NOT_LOCKED = 'No tokens locked';
	string internal constant AMOUNT_ZERO = 'Amount can not be 0';
    string internal constant NOT_ZERO_ADDRESS = 'CST: lock from the zero address';

    constructor() public ERC20("CoinButler", "CST") {
        _mint(msg.sender, initialSupply);
    }



    function multiTransfer(address[] memory _toList, uint256[] memory _valueList) public virtual returns (bool) {
        if(_toList.length != _valueList.length){
            revert();
        }
            
        for(uint256 i = 0; i < _toList.length; i++){
            transfer(_toList[i], _valueList[i]);
        }
            
        return true;
    }

    function lock(bytes32 _reason, uint256 _amount, uint256 _time, address _of) public override onlyOwner returns (bool) {
        require(_of != address(0), NOT_ZERO_ADDRESS);

        uint256 validUntil = block.timestamp.add(_time);
        require(_amount <= balances[_of], NOT_ENOUGH_TOKENS); 
        require(tokensLocked(_of, _reason) == 0, ALREADY_LOCKED);
        require(_amount != 0, AMOUNT_ZERO);

        if (locked[_of][_reason].amount == 0)
            lockReason[_of].push(_reason);

        balances[address(this)] = balances[address(this)].add(_amount);
        balances[_of] = balances[_of].sub(_amount);

        locked[_of][_reason] = lockToken(_amount, validUntil, false);

        // 수정
        emit Transfer(_of, address(this), _amount);
        emit Locked(_of, _reason, _amount, validUntil);
        return true;
    }

    function transferWithLock(address _to, bytes32 _reason, uint256 _amount, uint256 _time)
        public onlyOwner
        returns (bool)
    {
        require(_to != address(0), NOT_ZERO_ADDRESS);
        
        uint256 validUntil = block.timestamp.add(_time);
        require(tokensLocked(_to, _reason) == 0, ALREADY_LOCKED);
        require(_amount != 0, AMOUNT_ZERO);

        if (locked[_to][_reason].amount == 0)
            lockReason[_to].push(_reason);

        transfer(address(this), _amount);

        locked[_to][_reason] = lockToken(_amount, validUntil, false);
        
        emit Locked(_to, _reason, _amount, validUntil);
        return true;
    }

    function tokensLocked(address _of, bytes32 _reason)
        public override
        view
        returns (uint256 amount)
    {
        if (!locked[_of][_reason].claimed)
            amount = locked[_of][_reason].amount;
    }
    
    function tokensLockedAtTime(address _of, bytes32 _reason, uint256 _time)
        public override
        view
        returns (uint256 amount)
    {
        if (locked[_of][_reason].validity > _time)
            amount = locked[_of][_reason].amount;
    }

    function totalBalanceOf(address _of)
        public override
        view
        returns (uint256 amount)
    {
        amount = balanceOf(_of);

        for (uint256 i = 0; i < lockReason[_of].length; i++) {
            amount = amount.add((tokensLocked(_of, lockReason[_of][i])));
        }   
    }    

    function extendLock(bytes32 _reason, uint256 _time)
        public override onlyOwner
        returns (bool)
    {
        require(tokensLocked(msg.sender, _reason) > 0, NOT_LOCKED);

        locked[msg.sender][_reason].validity = locked[msg.sender][_reason].validity.add(_time);

        emit Locked(msg.sender, _reason, locked[msg.sender][_reason].amount, locked[msg.sender][_reason].validity);
        return true;
    }

    function increaseLockAmount(bytes32 _reason, uint256 _amount)
        public override onlyOwner
        returns (bool)
    {
        require(tokensLocked(msg.sender, _reason) > 0, NOT_LOCKED);
        transfer(address(this), _amount);

        locked[msg.sender][_reason].amount = locked[msg.sender][_reason].amount.add(_amount);

        emit Locked(msg.sender, _reason, locked[msg.sender][_reason].amount, locked[msg.sender][_reason].validity);
        return true;
    }


    function tokensUnlockable(address _of, bytes32 _reason)
        public override
        view
        returns (uint256 amount)
    {
        if (locked[_of][_reason].validity <= block.timestamp && !locked[_of][_reason].claimed)
            amount = locked[_of][_reason].amount;
    }

     function unlock(address _of)
        public override onlyOwner
        returns (uint256 unlockableTokens)
    {
        require(_of != address(0), NOT_ZERO_ADDRESS);
        uint256 lockedTokens;
        
        for (uint256 i = 0; i < lockReason[_of].length; i++) {
            lockedTokens = tokensUnlockable(_of, lockReason[_of][i]);
            if (lockedTokens > 0) {
                unlockableTokens = unlockableTokens.add(lockedTokens);
                locked[_of][lockReason[_of][i]].claimed = true;
                emit Unlocked(_of, lockReason[_of][i], lockedTokens);
            }
        }  

        if (unlockableTokens > 0)
            this.transfer(_of, unlockableTokens);
    }

    function getUnlockableTokens(address _of)
        public override
        view
        returns (uint256 unlockableTokens)
    {
        for (uint256 i = 0; i < lockReason[_of].length; i++) {
            unlockableTokens = unlockableTokens.add((tokensUnlockable(_of, lockReason[_of][i])));
        }  
    }
    
    function mint(address holder, uint256 amount)
        public onlyOwner 
    {
        _mint(holder, amount);
    }

    function burn(uint256 amount)
        public onlyOwner returns (bool success){
            _burn(msg.sender, amount);

            return true;
        }

    function burnFrom(address account, uint256 amount)
        public onlyOwner {
            uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount);

            _approve(account, _msgSender(), decreasedAllowance);
            _burn(account, amount);
        }    
     
}