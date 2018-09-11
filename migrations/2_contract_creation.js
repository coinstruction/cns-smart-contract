const CoinStructureCrowdsale = artifacts.require("./CoinStructureCrowdsale.sol");
const CoinStructureToken = artifacts.require("./CoinStructureToken.sol");
const TokenDeskProxy = artifacts.require("./TokenDeskProxy.sol");
const TOKEN_DESK_BONUS = 6;
const MINTER_ADDRESS = 0x0594C787d906f68d57C7920F67386696a56C2Dbd;

module.exports = function(deployer, network, addresses) {
	deployer.deploy(CoinStructureToken).then(() => {
		return deployer.deploy(CoinStructureCrowdsale, CoinStructureToken.address);
	}).then(() => {
		return CoinStructureToken.deployed();
	}).then((token) => {
		return token.transferOwnership(CoinStructureCrowdsale.address);
	}).then(() => {
		return deployer.deploy(TokenDeskProxy, CoinStructureCrowdsale.address, TOKEN_DESK_BONUS);
	}).then(() => {
		return CoinStructureCrowdsale.deployed();
	}).then((contract) => {
		return contract.setTokenDeskProxy(TokenDeskProxy.address);
	}).then(() => {
		return CoinStructureCrowdsale.deployed();
	}).then((contract) => {
		return contract.setTokenMinter(MINTER_ADDRESS);
	});
};
