// Get the instance of NFT Contract
const nftContract = artifacts.require("NftTicketing");

module.exports = async function(deployer) {
    // Deploying the contract
    await deployer.deploy(nftContract);
    const contract = await nftContract.deployed();

    // Mint 5 tickets
    await contract.reserveNfts(5);
    console.log("5 NFT Tickets have been minted!");
};