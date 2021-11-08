const TokenTimelock = artifacts.require("TokenTimelock");

module.exports = function (deployer) {
  deployer.deploy(TokenTimelock);
};
