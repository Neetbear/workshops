const { ethers } = require('hardhat');
const { signMetaTxRequest } = require('../src/signer');
const { readFileSync, writeFileSync } = require('fs');

const DEFAULT_NAME = 'sign-test-swap';

function getInstance(name) {
  const address = JSON.parse(readFileSync('deploy.json'))[name];
  if (!address) throw new Error(`Contract ${name} not found in deploy.json`);
  return ethers.getContractFactory(name).then(f => f.attach(address));
}

function getInstanceTest(name) {
  const address = JSON.parse(readFileSync('deployTest.json'))[name];
  if (!address) throw new Error(`Contract ${name} not found in deployTest.json`);
  return ethers.getContractFactory(name).then(f => f.attach(address));
}

async function main() {
  const forwarder = await getInstance("MinimalForwarder");
  const myToken = await getInstanceTest('MyToken');
  const test = await getInstanceTest("Test");
  console.log(forwarder.address);

  const { VALUE: value, PRIVATE_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;
  console.log(`Token transfer to : ${test.address}, amount : ${value} from ${from}...`);
  const data = test.interface.encodeFunctionData('_safeTransferFrom', [test.address, value]);

 const result = await signMetaTxRequest(signer, forwarder, {
    to: test.address, from, data
  });

  writeFileSync('tmp/request.json', JSON.stringify(result, null, 2));
  console.log(`Signature: `, result.signature);
  console.log(`Request: `, result.request);
}

if (require.main === module) {
  main().then(() => process.exit(0))
    .catch(error => { console.error(error); process.exit(1); });
}