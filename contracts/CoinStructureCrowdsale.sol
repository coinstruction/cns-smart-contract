pragma solidity 0.4.24;

import "zeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

import "./CoinStructureToken.sol";
import "./TokenDeskProxyAware.sol";
import "./EscrowVault.sol";

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

    uint256 public constant START_TIME = 1543658400; // 2018-12-01 10:00 UTC +0
    uint256 public icoEndTime = 1552644000; // 2019-03-15 10:00 UTC +0 

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
        stages.push(Stage({ till: 1546336800, bonus: 0, cap: 60000000e18 }));   // 2019-01-01 10:00 UTC +0
        stages.push(Stage({ till: 1549015200, bonus: 0, cap: 35000000e18 }));   // 2019-02-01 10:00 UTC +0
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
