pragma solidity 0.4.24;


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * See https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address _who) public view returns (uint256);
  function transfer(address _to, uint256 _value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address _owner, address _spender)
    public view returns (uint256);

  function transferFrom(address _from, address _to, uint256 _value)
    public returns (bool);

  function approve(address _spender, uint256 _value) public returns (bool);
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}



/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
  function safeTransfer(
    ERC20Basic _token,
    address _to,
    uint256 _value
  )
    internal
  {
    require(_token.transfer(_to, _value));
  }

  function safeTransferFrom(
    ERC20 _token,
    address _from,
    address _to,
    uint256 _value
  )
    internal
  {
    require(_token.transferFrom(_from, _to, _value));
  }

  function safeApprove(
    ERC20 _token,
    address _spender,
    uint256 _value
  )
    internal
  {
    require(_token.approve(_spender, _value));
  }
}


/**
 * @title TokenTimelock
 * @dev TokenTimelock is a token holder contract that will allow a
 * beneficiary to extract the tokens after a given release time
 */
contract TokenTimelock {
  using SafeERC20 for ERC20Basic;

  // ERC20 basic token contract being held
  ERC20Basic public token;

  // beneficiary of tokens after they are released
  address public beneficiary;

  // timestamp when token release is enabled
  uint256 public releaseTime;

  constructor(
    ERC20Basic _token,
    address _beneficiary,
    uint256 _releaseTime
  )
    public
  {
    // solium-disable-next-line security/no-block-members
    require(_releaseTime > block.timestamp);
    token = _token;
    beneficiary = _beneficiary;
    releaseTime = _releaseTime;
  }

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function release() public {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp >= releaseTime);

    uint256 amount = token.balanceOf(address(this));
    require(amount > 0);

    token.safeTransfer(beneficiary, amount);
  }
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (_a == 0) {
      return 0;
    }

    c = _a * _b;
    assert(c / _a == _b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
    // assert(_b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = _a / _b;
    // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
    return _a / _b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
    assert(_b <= _a);
    return _a - _b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
    c = _a + _b;
    assert(c >= _a);
    return c;
  }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   * @notice Renouncing to ownership will leave the contract without an owner.
   * It will not be possible to call the functions with the `onlyOwner`
   * modifier anymore.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = address(0);
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function transferOwnership(address _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }

  /**
   * @dev Transfers control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function _transferOwnership(address _newOwner) internal {
    require(_newOwner != address(0));
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */


contract CoinStructureToken is ERC20, Ownable {
    using SafeMath for uint256;

    string public constant name = "Coins";
    string public constant symbol = "CNS";
    uint8 public constant decimals = 18;

    mapping (address => uint256) private balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);

    bool public mintingFinished = false;
    bool public transferEanbled = true;

    uint256 private totalSupply_;

    modifier canTransfer() {
        require(transferEanbled);
        _;
    }

    /**
    * @dev total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public canTransfer returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        // SafeMath.sub will throw if there is not enough balance.
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    /**
    * @dev Transfer tokens from one address to another
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint256 the amount of tokens to be transferred
    */
    function transferFrom(address _from, address _to, uint256 _value) public canTransfer returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    *
    * Beware that changing an allowance with this method brings the risk that someone may use both the old
    * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
    * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
    * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    * @param _spender The address which will spend the funds.
    * @param _value The amount of tokens to be spent.
    */
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
    * @dev Function to check the amount of tokens that an owner allowed to a spender.
    * @param _owner address The address which owns the funds.
    * @param _spender address The address which will spend the funds.
    * @return A uint256 specifying the amount of tokens still available for the spender.
    */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    /**
    * @dev Increase the amount of tokens that an owner allowed to a spender.
    *
    * approve should be called when allowed[_spender] == 0. To increment
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _addedValue The amount of tokens to increase the allowance by.
    */
    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
    * @dev Decrease the amount of tokens that an owner allowed to a spender.
    *
    * approve should be called when allowed[_spender] == 0. To decrement
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _subtractedValue The amount of tokens to decrease the allowance by.
    */
    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
    * @dev Burns a specific amount of tokens.
    * @param _value The amount of token to be burned.
    */
    function burn(uint256 _value) public {
        _burn(msg.sender, _value);
    }

    function _burn(address _who, uint256 _value) internal {
        require(_value <= balances[_who]);
        // no need to require value <= totalSupply, since that would imply the
        // sender's balance is greater than the totalSupply, which *should* be an assertion failure

        balances[_who] = balances[_who].sub(_value);
        totalSupply_ = totalSupply_.sub(_value);
        emit Burn(_who, _value);
        emit Transfer(_who, address(0), _value);
    }

    modifier canMint() {
        require(!mintingFinished);
        _;
    }

    /**
    * @dev Function to mint tokens
    * @param _to The address that will receive the minted tokens.
    * @param _amount The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(address _to, uint256 _amount) public onlyOwner canMint returns (bool) {
        totalSupply_ = totalSupply_.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    /**
    * @dev Function to stop minting new tokens.
    * @return True if the operation was successful.
    */
    function finishMinting() public onlyOwner canMint returns (bool) {
        mintingFinished = true;
        transferEanbled = true;
        emit MintFinished();
        return true;
    }
}

contract TokenDeskProxySupport {
    function buyTokens(address sender_, address benefeciary_, uint256 tokenDeskBonus_) external payable;
}


contract TokenDeskProxyAware is TokenDeskProxySupport, Ownable {

    address private tokenDeskProxy;

    modifier onlyTokenDeskProxy() {
        require(msg.sender == tokenDeskProxy);
        _;
    }

    function buyTokens(address beneficiary) public payable {
        internalBuyTokens(msg.sender, beneficiary, 0);
    }

    function buyTokens(address sender, address beneficiary, uint256 tokenDeskBonus) external payable onlyTokenDeskProxy {
        internalBuyTokens(sender, beneficiary, tokenDeskBonus);
    }

    function setTokenDeskProxy(address tokenDeskProxy_) public onlyOwner {
        require(tokenDeskProxy_ != address(0));
        tokenDeskProxy = tokenDeskProxy_;
    }

    function internalBuyTokens(address sender, address beneficiary, uint256 tokenDeskBonus) internal;
}


/**
 * The EscrowVault contract collects crowdsale ethers and allows to refund
 * if softcap soft cap is not reached.
 */
contract EscrowVault is Ownable {
  using SafeMath for uint256;

  enum State { Active, Refunding, GoalReached, Closed }

  mapping (address => uint256) public deposited;
  address public beneficiary;
  address public superOwner;
  State public state;

  event GoalReached();
  event RefundsEnabled();
  event Refunded(address indexed beneficiary, uint256 weiAmount);
  event Withdrawal(uint256 weiAmount);
  event Close();

  constructor(address _superOwner, address _beneficiary) public {
    require(_beneficiary != address(0));
    require(_superOwner != address(0));
    beneficiary = _beneficiary;
    superOwner = _superOwner;
    state = State.Active;
  }

  function deposit(address investor) onlyOwner public payable {
    require(state == State.Active || state == State.GoalReached);
    deposited[investor] = deposited[investor].add(msg.value);
  }

  function setGoalReached() onlyOwner public {
    require (state == State.Active);
    state = State.GoalReached;
    emit GoalReached();
  }

  function withdraw(uint256 _amount) public {
    require(msg.sender == superOwner);
    require(state == State.GoalReached);
    require (_amount <= address(this).balance &&  _amount > 0);
    beneficiary.transfer(_amount);
    emit Withdrawal(_amount);
  }

  function withdrawAll() onlyOwner public {
    require(state == State.GoalReached);
    uint256 balance = address(this).balance;
    emit Withdrawal(balance);
    beneficiary.transfer(balance);
  }

  function close() onlyOwner public {
    require (state == State.GoalReached);
    withdrawAll();
    state = State.Closed;
    emit Close();
  }

  function enableRefunds() onlyOwner public {
    require(state == State.Active);
    state = State.Refunding;
    emit RefundsEnabled();
  }

  function refund(address investor) public {
    require(state == State.Refunding);
    uint256 depositedValue = deposited[investor];
    deposited[investor] = 0;
    investor.transfer(depositedValue);
    emit Refunded(investor, depositedValue);
  }
}


contract CoinStructureCrowdsale is TokenDeskProxyAware {
    using SafeMath for uint256;
    // Wallet where all ether will be moved after escrow withdrawal. Can be even multisig wallet
    address public constant WALLET = 0x1000000000000000000000000000000000000000;
    // Wallet for bonus tokens
    address public constant ICO_BONUS_WALLET = 0x2000000000000000000000000000000000000000;
    // Wallet for advisors tokens
    address public constant ADVISORS_WALLET = 0x3000000000000000000000000000000000000000;
    // Wallet for team tokens
    address public constant TEAM_WALLET = 0x4000000000000000000000000000000000000000;
    // Wallet for maintenance fund
    address public constant MAINTENANCE_WALLET = 0x5000000000000000000000000000000000000000;
    // Wallet for ambasadors tokens
    address public constant AMBASADORS_WALLET = 0x6000000000000000000000000000000000000000;
    // Wallet for bounty tokens
    address public constant BOUNTY_WALLET = 0x7000000000000000000000000000000000000000;

    uint256 public rate = 4375; // 1 token price in ETH when ETH/USD rate is 280
    uint256 public constant PRICE = 64; // 0.064 USD
    uint256 public constant TEAM_TOKENS_LOCK_PERIOD = 60 * 60 * 24 * 365; // 365 days
    uint256 public constant TEAM_TOKENS_LOCK_PERIOD2 = 60 * 60 * 24 * 730; // 730 days
    uint256 public constant ADVISORS_TOKENS_LOCK_PERIOD = 60 * 60 * 24 * 180; // 365 days
    uint256 public constant ADVISORS_TOKENS_LOCK_PERIOD2 = 60 * 60 * 24 * 185; // 730 days
    uint256 public constant SOFT_CAP = 25000000e18; // 25 000 000
    uint256 public constant ICO_TOKENS = 125000000e18; // 125 000 000
    uint256 public constant ICO_BONUS_TOKENS = 50000000e18; // 50 000 000
    uint256 public constant ADVISORS_TOKENS = 25000000e18; // 25 000 000
    uint256 public constant TEAM_TOKENS = 17500000e18; // 17 500 000
    uint256 public constant MAINTENANCE_TOKENS = 15000000e18; // 15 000 000
    uint256 public constant AMBASADORS_TOKENS = 12500000e18; // 12 500 000
    uint256 public constant BOUNTY_TOKENS = 5000000e18; // 5 000 000

    uint256 public constant LARGE_PURCHASE = 1000000e18; // 1 000 000 tokens
    uint8 public constant LARGE_PURCHASE_BONUS = 0;

    uint256 public constant START_TIME = 1538388000; // 2018-10-01 10:00 UTC +0
    uint256 public icoEndTime = 1545213600; // 2018-12-19 10:00 UTC +0 

    Stage[] internal stages;

    struct Stage {
        uint256 cap;
        uint64 till;
        uint8 bonus;
    }

    // The token being sold
    CoinStructureToken public token;

    // amount of raised money in wei
    uint256 public weiRaised;

    // refund vault used to hold funds while crowdsale is running
    EscrowVault public vault;

    uint256 public currentStage = 0;
    bool public isFinalized = false;
    bool public isPrivateTokensReleased = false;

    address private tokenMinter;
    address private rateUpdater;

    TokenTimelock public teamTimelock;
    TokenTimelock public teamTimelock2;
    TokenTimelock public advisorsTimelock;
    TokenTimelock public advisorsTimelock2;

    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    event Finalized();
    /**
     * When there no tokens left to mint and token minter tries to manually mint tokens
     * this event is raised to signal how many tokens we have to charge back to purchaser
     */
    event ManualTokenMintRequiresRefund(address indexed purchaser, uint256 value);

    constructor(address _token) public {
        stages.push(Stage({ till: 1542276000, bonus: 0, cap: 60000000e18 }));   // 2018-07-15 12:00 UTC +0
        stages.push(Stage({ till: 1544349600, bonus: 0, cap: 35000000e18 }));   // 2018-07-15 12:00 UTC +0
        stages.push(Stage({ till: ~uint64(0), bonus: 0, cap: 30000000e18 }));   // unlimited

        token = CoinStructureToken(_token);
        vault = new EscrowVault(msg.sender, WALLET);  // Wallet where all ether will be stored during ICO
    }

    modifier onlyTokenMinterOrOwner() {
        require(msg.sender == tokenMinter || msg.sender == owner);
        _;
    }

    modifier onlyRateUpdaterOrOwner() {
        require(msg.sender == rateUpdater || msg.sender == owner);
        _;
    }

    function internalBuyTokens(address sender, address beneficiary, uint256 tokenDeskBonus) internal {
        require(beneficiary != address(0));
        require(sender != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 nowTime = getNow();
        // this loop moves stages and ensures correct stage according to date
        while (currentStage < stages.length && stages[currentStage].till < nowTime) {
            // move all unsold tokens to next stage
            uint256 nextStage = currentStage.add(1);
            stages[nextStage].cap = stages[nextStage].cap.add(stages[currentStage].cap);
            stages[currentStage].cap = 0;
            currentStage = nextStage;
        }

        // calculate token amount to be created
        uint256 tokens = calculateTokens(weiAmount, tokenDeskBonus);

        uint256 excess = appendContribution(beneficiary, tokens);

        uint256 refund = (excess > 0 ? excess.mul(weiAmount).div(tokens) : 0);
        weiAmount = weiAmount.sub(refund);
        weiRaised = weiRaised.add(weiAmount);

        if (refund > 0) { // hard cap reached, no more tokens to mint
            sender.transfer(refund);
        }

        emit TokenPurchase(sender, beneficiary, weiAmount, tokens.sub(excess));

        if (goalReached() && vault.state() == EscrowVault.State.Active) {
            vault.setGoalReached();
        }
        vault.deposit.value(weiAmount)(sender);
    }

    function calculateTokens(uint256 _weiAmount, uint256 _tokenDeskBonus) internal view returns (uint256) {
        uint256 tokens = _weiAmount.mul(rate);

        if (stages[currentStage].bonus > 0) {
            uint256 stageBonus = tokens.mul(stages[currentStage].bonus).div(100);
            tokens = tokens.add(stageBonus);
        }

        if (currentStage < 1) return tokens;

        uint256 bonus = _tokenDeskBonus.add(tokens >= LARGE_PURCHASE ? LARGE_PURCHASE_BONUS : 0);
        return tokens.add(tokens.mul(bonus).div(100));
    }

    function updateETHUSDRate(uint256 _rateETHUSD) public onlyRateUpdaterOrOwner {
        uint256 newRate = _rateETHUSD.div(PRICE);
        require(rate.mul(70).div(100) <= newRate && newRate <= rate.mul(130).div(100) );
        rate = newRate;
    }

    function appendContribution(address _beneficiary, uint256 _tokens) internal returns (uint256) {
        uint256 excess = _tokens;
        uint256 tokensToMint = 0;

        while (excess > 0 && currentStage < stages.length) {
            Stage storage stage = stages[currentStage];
            if (excess >= stage.cap) {
                excess = excess.sub(stage.cap);
                tokensToMint = tokensToMint.add(stage.cap);
                stage.cap = 0;
                currentStage = currentStage.add(1);
            } else {
                stage.cap = stage.cap.sub(excess);
                tokensToMint = tokensToMint.add(excess);
                excess = 0;
            }
        }
        if (tokensToMint > 0) {
            token.mint(_beneficiary, tokensToMint);
        }
        return excess;
    }

    // @return true if the transaction can buy tokens
    function validPurchase() internal view returns (bool) {
        bool withinPeriod = getNow() >= START_TIME && getNow() <= icoEndTime;
        bool nonZeroPurchase = msg.value != 0;
        bool canMint = token.totalSupply() < ICO_TOKENS;
        bool validStage = (currentStage < stages.length);
        bool stageCapReached = (currentStage > 0 && stages[currentStage - 1].till > getNow());
        return withinPeriod && nonZeroPurchase && canMint && validStage && !stageCapReached;
    }

    // if crowdsale is unsuccessful, investors can claim refunds here
    function claimRefund() public {
        require(isFinalized);
        require(!goalReached());

        vault.refund(msg.sender);
    }

    // if goal is reached 
    function releaseTokens() public onlyTokenMinterOrOwner {
        if (goalReached() && !isPrivateTokensReleased) {
            token.mint(ICO_BONUS_WALLET, ICO_BONUS_TOKENS);
            token.mint(MAINTENANCE_WALLET, MAINTENANCE_TOKENS);
            token.mint(AMBASADORS_WALLET, AMBASADORS_TOKENS);
            token.mint(BOUNTY_WALLET, BOUNTY_TOKENS);
            isPrivateTokensReleased = true;
        }
    }

    /**
    * @dev Must be called after crowdsale ends, to do some extra finalization
    * work. Calls the contract's finalization function.
    */
    function finalize() public onlyOwner {
        require(!isFinalized);
        require(getNow() > icoEndTime || token.totalSupply() == ICO_TOKENS);

        if (goalReached()) {
            // Close escrowVault and transfer all collected ethers into WALLET address
            if (vault.state() != EscrowVault.State.Closed) {
                vault.close();
            }

            if(currentStage < stages.length) {
                token.mint(MAINTENANCE_WALLET, stages[currentStage].cap);
            }

            teamTimelock = new TokenTimelock(token, TEAM_WALLET, getNow().add(TEAM_TOKENS_LOCK_PERIOD));
            token.mint(teamTimelock, TEAM_TOKENS.div(2));
            teamTimelock2 = new TokenTimelock(token, TEAM_WALLET, getNow().add(TEAM_TOKENS_LOCK_PERIOD2));
            token.mint(teamTimelock2, TEAM_TOKENS.div(2));

            advisorsTimelock = new TokenTimelock(token, ADVISORS_WALLET, getNow().add(ADVISORS_TOKENS_LOCK_PERIOD));
            token.mint(advisorsTimelock, ADVISORS_TOKENS.div(2));
            advisorsTimelock2 = new TokenTimelock(token, ADVISORS_WALLET, getNow().add(ADVISORS_TOKENS_LOCK_PERIOD2));
            token.mint(advisorsTimelock2, ADVISORS_TOKENS.div(2));

            releaseTokens();

            token.finishMinting();
            token.transferOwnership(token);
        } else {
            vault.enableRefunds();
        }
        emit Finalized();
        isFinalized = true;
    }

    function goalReached() public view returns (bool) {
        return token.totalSupply() >= SOFT_CAP;
    }

    // fallback function can be used to buy tokens or claim refund
    function () external payable {
        if (!isFinalized) {
            buyTokens(msg.sender);
        } else {
            claimRefund();
        }
    }

    function mintTokens(address[] _receivers, uint256[] _amounts) external onlyTokenMinterOrOwner {
        require(_receivers.length > 0 && _receivers.length <= 100);
        require(_receivers.length == _amounts.length);
        require(!isFinalized);
        for (uint256 i = 0; i < _receivers.length; i++) {
            address receiver = _receivers[i];
            uint256 amount = _amounts[i];

            require(receiver != address(0));
            require(amount > 0);

            uint256 excess = appendContribution(receiver, amount);

            if (excess > 0) {
                emit ManualTokenMintRequiresRefund(receiver, excess);
            }
        }
    }

    function setIcoEndTime(uint256 _endTime) public onlyOwner {
        require(_endTime > START_TIME && _endTime > getNow());
        icoEndTime = _endTime;
    }

    function setTokenMinter(address _tokenMinter) public onlyOwner {
        require(_tokenMinter != address(0));
        tokenMinter = _tokenMinter;
    }

    function setRateUpdater(address _rateUpdater) public onlyOwner {
        require(_rateUpdater != address(0));
        rateUpdater = _rateUpdater;
    }

    function getNow() internal view returns (uint256) {
        return now;
    }
}
