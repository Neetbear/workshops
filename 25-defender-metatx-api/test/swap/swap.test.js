const { expect } = require("chai").use(require('chai-as-promised'));
const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { relay } = require('../../autotasks/relay');

async function deploy(name, ...params) {
  const Contract = await ethers.getContractFactory(name);
  return await Contract.deploy(...params).then(f => f.deployed());
}

describe("swap modal test", function() {
  beforeEach(async function() {
    this.forwarder = await deploy('MinimalForwarder');
    this.token = await deploy("MyToken", "TestToken", "TTT", "0x191a0b6268C7aeaaE8C2e35Ff01199875ef49104");
    this.swap = await deploy("TestSwap", token.address, "TestKey", this.forwarder.address, 100000000);
    this.accounts = await ethers.getSigners();
  });

  it("test for swap", async function() {
    const { token, swap } = this;
    const signer = this.accounts[2];
    const relayer = this.accounts[3];
    const forwarder = this.forwarder.connect(relayer);

    await token.mint(swap.address, 100000000).then(tx => tx.wait());
    await token.mint(signer, 10000).then(tx => tx.wait());
    await token.approval(swap.address, 1000).then(tx => tx.wait());

    const { request, signature } = await signMetaTxRequest(signer.provider, forwarder, {
      from: signer.address,
      to: swap.address,
      data: swap.interface.encodeFunctionData('swap', ['meta-txs']),
    });
    
    const whitelist = [swap.address]
    await relay(forwarder, request, signature, whitelist);

    expect(await registry.owners('meta-txs')).to.equal(signer.address);
    expect(await registry.names(signer.address)).to.equal('meta-txs');
  });
});
