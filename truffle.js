module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
      rinkeby: {
        host: "localhost",
        port: 8545,
        network_id: "4",
        gas: 6713094,
        gasPrice: 5000000000,
        from: '0x9f3E02A42EA420Df52481a215e88AbA4b29f5012'
      },
      test: {
        host: "localhost",
        port: 8545,
        network_id: "*", // Match any network id
        gas: 6713094
      },
      development: {
        host: "localhost",
        port: 8545,
        network_id: "*",
        gas: 6713094
      },
      live: {
        host: "localhost",  // Change into main net node address
        port: 8545,
        network_id: "1",
        gas: 6713094,
        gasPrice: 5000000000,
        from: "0x0000000000000000000000000000000000000000"
      }
  }
};
