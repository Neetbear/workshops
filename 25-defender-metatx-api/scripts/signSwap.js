const { ethers } = require('hardhat');
const { signMetaTxRequest } = require('../src/signer');
const { readFileSync, writeFileSync } = require('fs');

const DEFAULT_NAME = 'sign-test-swap';

function getInstance(name) {
  const address = JSON.parse(readFileSync('deploy.json'))[name];
  if (!address) throw new Error(`Contract ${name} not found in deploy.json`);
  return ethers.getContractFactory(name).then(f => f.attach(address));
}

function getInstanceSwap(name) {
  const address = JSON.parse(readFileSync('deploySwap.json'))[name];
  if (!address) throw new Error(`Contract ${name} not found in deploy.json`);
  return ethers.getContractFactory(name).then(f => f.attach(address));
}

async function main() {
  const forwarder = await getInstance("MinimalForwarder");
  const testToken = await getInstanceSwap('MyToken');
  const testSwap = await getInstanceSwap("TestSwap");
  console.log(forwarder.address);

  const { AMOUNT0IN: amount0In, AMOUNT1IN: amount1In, PRIVATE_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;
  console.log(`Token Swaping token0In of ${amount0In || 0} or token1In of ${amount1In || 0} as ${from}...`);
  const data = testSwap.interface.encodeFunctionData('swap', [amount0In || 0, amount1In || 0, "TestKey"]);

 const result = await signMetaTxRequest(signer, forwarder, {
    to: testSwap.address, from, data
  });

  writeFileSync('tmp/request.json', JSON.stringify(result, null, 2));
  console.log(`Signature: `, result.signature);
  console.log(`Request: `, result.request);
}

if (require.main === module) {
  main().then(() => process.exit(0))
    .catch(error => { console.error(error); process.exit(1); });
}