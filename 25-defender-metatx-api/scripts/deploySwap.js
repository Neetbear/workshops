const {
  DefenderRelayProvider,
  DefenderRelaySigner,
} = require('defender-relay-client/lib/ethers')
const { ethers } = require('hardhat')
const { readFileSync, writeFileSync } = require('fs')

function getInstance(name) {
  const address = JSON.parse(readFileSync('deploy.json'))[name];
  if (!address) throw new Error(`Contract ${name} not found in deploy.json`);
  return ethers.getContractFactory(name).then(f => f.attach(address));
}

async function main() {
  require('dotenv').config()
  const credentials = {
    apiKey: process.env.RELAYER_API_KEY,
    apiSecret: process.env.RELAYER_API_SECRET,
  }
  const provider = new DefenderRelayProvider(credentials)
  const relaySigner = new DefenderRelaySigner(credentials, provider, {
    speed: 'fast',
  })

  const Token = await ethers.getContractFactory('MyToken')
  const token = await Token.connect(relaySigner)
    .deploy("TestToken", "TTT", "0x191a0b6268C7aeaaE8C2e35Ff01199875ef49104")
    .then((f) => f.deployed())

  const MinimalForwarder = await getInstance('MinimalForwarder');

  const TestSwap = await ethers.getContractFactory('TestSwap')
  const testSwap = await TestSwap.connect(relaySigner)
    .deploy(token.address, "TestKey", MinimalForwarder.address, 100000000)
    .then((f) => f.deployed())

  writeFileSync(
    'deploySwap.json',
    JSON.stringify(
      {
        MyToken: token.address,
        TestSwap: testSwap.address,
      },
      null,
      2
    )
  )

  console.log(
    `MyToken: ${token.address}\nTestSwap: ${testSwap.address}`
  )
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error)
      process.exit(1)
    })
}
