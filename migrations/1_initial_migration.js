const SampleNFT = artifacts.require("SampleNFT");

module.exports = function (deployer) {
  deployer.deploy(SampleNFT);
};
