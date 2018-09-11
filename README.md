# CoinStructure
Smart Contracts for coinstruction.com ICO

## Usage

### CoinStructureCrowdsale

Crowdsale contract deployment consumes around 4 800 000 amount of gas. The smart-contract starts token sale after crowdsale start (`START_TIME` constant) and before crowdsale end (`icoEndTime` state variable). The crowdsale end date can be changed by calling `setIcoEndTime` function, but it have to be greater than current time. This function can be called only by the owner of the crowdsale smart-contract.

During ICO smart-contract will collect funds to EscrowVault contract. When soft-cap is reached it is possible to withdraw collected funds by calling `withdraw(uint256 weiAmount)` function of EscrowVault contract. This call will transfer chosen amount of collected funds to the `WALLET` address. This can be done only by the owner.

After crowdsale ends, owner must call `finalize` function. In case of successfull ICO (soft cap reached) this call will withdraw funds which were collected during ICO. In case of unsuccessful ICO (soft cap not reached) this call will unlock investor funds which can be returned by sending 0 ether to smart-contract or by calling `claimRefund` function.

A `finalize` function call will also stop token minting and transfer ownership of a token to token itself. This ensures that no one will ever have control over CoinStructureToken smart-contract.

Smart-contract also supports manual token minting by calling `mintTokens(address[] _receivers, uint256[] _amounts)` function. This function can be called either by smart-contract owner or by a special account which can be set by calling `setTokenMinter` function. Only smart-contract owner can call `setTokenMinter` function.

`mintTokens(address[] _receivers, uint256[] _amounts)` function accepts two arguments. The first one is an array with addresses, the second one is an array with token amounts which must be assigned to appropriate address. Array lengths must be the same and must not exceed 100 items. When calling this function an event `ManualTokenMintRequiresRefund` can be raised. This event is used to signal that tokens which are to be distributed in an ICO are over. This event also contains information how much tokens cannot be minted and a refund to an address must be applied.

### CoinStructureToken

Token contract deployment consumes around 1 700 000 amount of gas. Token contract is a standard ERC20 contract. Token transfers is enabled only after token minting is finished (`CoinStructureCrowdsale.finalize()` function call).

### TokenDeskProxy

TokenDeskProxy smart-contract allows crowdsale smart-contract to assign an additional bonus to an inversor. To get additional bonus investor must deposit funds to this proxy contract. Then this contract will redirect received funds to the crowdsale contract with an additional bonus. TokenDesk bonus is specified at smart-contract deployment and cannot be changed. If bonus have to be changed new TokenDeskProxy proxy smart-contract must be deployed with new bonus value and address of TokenDeskProxy smart-contract must be specified through `CoinStructureCrowdsale.setTokenDeskProxy()` function call.
