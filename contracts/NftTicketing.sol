// SPDX-License-Identifier: MIT
// Indicates the license type for the contract.
pragma solidity ^0.8.19;
// Specifies the required Solidity version for the contract.

// Import necessary contracts from the OpenZeppelin library.
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Defining the contract named "NftTicketing" which inherits from multiple contracts.
contract NftTicketing is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    // Using the Counters library to manage token IDs.
    using Counters for Counters.Counter;
    
    // Creating a counter to keep track of token IDs.
    Counters.Counter private _tokenIds;

    // Defining constants for the maximum supply of tickets and maximum tickets that can be minted at once.
    uint public constant MAX_SUPPLY = 10000;
    uint public constant MAX_PER_MINT = 5;

    // String to store the base token URI for metadata.
    string public baseTokenURI;

    // Setting the price of a single ticket in ether.
    uint public price = 0.05 ether;

    // Flag to indicate whether the sale is active or not.
    bool public saleIsActive = false;

    // Constructor for initializing the contract with a name and ticker for the NFT collection.
    constructor() ERC721("My NFT Tickets", "MNT") {}

    mapping(address => bool) canMintMultiple;

    // Function that allowlists addresses to hold multiple NFTs.
    function addToAllowlist(address[] calldata _wAddresses) public onlyOwner {
        for (uint i = 0; i < _wAddresses.length; i++) {
            canMintMultiple[_wAddresses[i]] = true;
        }
    }

    // Function to generate NFT metadata based on the given token ID.
    function generateMetadata(uint tokenId) public pure returns (string memory) {
        // SVG template for the NFT image.
        string memory svg = string(abi.encodePacked(
            "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinyMin meet' viewBox='0 0 350 350'>",
            "<style>.base { fill: white; font-family: serif; font-size: 25px; }</style>",
            "<rect width='100%' height='100%' fill='red' />",
            "<text x='50%' y='40%' class='base' dominant-baseline='middle' text-anchor='middle'>",
            "<tspan y='50%' x='50%'>NFT Ticket #",
            Strings.toString(tokenId),
            "</tspan></text></svg>"
        ));

        // Encode SVG to Base64 and embed it in the JSON metadata.
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "NFT Ticket #',
                        Strings.toString(tokenId),
                        '", "description": "A ticket that gives you access to a cool event!", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '", "attributes": [{"trait_type": "Type", "value": "Base Ticket"}]}'
                    )
                )
            )
        );

        // Combine the metadata JSON with the appropriate prefix.
        string memory metadata = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        return metadata;
    }

    // Function to reserve NFTs to the creator's wallet.
    function reserveNfts(uint _count) public onlyOwner {
        // Get the next available token ID.
        uint nextId = _tokenIds.current();

        // Ensure that there are enough tokens left to reserve.
        require(nextId + _count < MAX_SUPPLY, "Not enough NFTs left to reserve");

        // Mint the specified number of reserved NFTs.
        for (uint i = 0; i < _count; i++) {
            string memory metadata = generateMetadata(nextId + i);
            _mintSingleNft(msg.sender, metadata);
        }
    }

    // Function to airdrop NFTs to specified addresses.
    function airDropNfts(address[] calldata _wAddresses) public onlyOwner {
        // Get the next available token ID.
        uint nextId = _tokenIds.current();
        uint count = _wAddresses.length;

        // Ensure that there are enough tokens left to airdrop.
        require(nextId + count < MAX_SUPPLY, "Not enough NFTs left to reserve");

        // Mint NFTs for each specified address.
        for (uint i = 0; i < count; i++) {
            string memory metadata = generateMetadata(nextId + i);
            _mintSingleNft(_wAddresses[i], metadata);
        }
    }

    // Function to set the sale state (active or not).
    function setSaleState(bool _activeState) public onlyOwner {
        saleIsActive = _activeState;
    }

    // Function to allow the public to mint NFTs during the sale.
    function mintNfts(uint _count) public payable {
        // Get the next available token ID.
        uint nextId = _tokenIds.current();

        // Various requirements to mint NFTs.
        require(nextId + _count < MAX_SUPPLY, "Not enough NFT tickets left!");
        require(_count > 0 && _count <= MAX_PER_MINT, "Cannot mint specified number of NFT tickets.");
        require(saleIsActive, "Sale is not currently active!");
        require(msg.value >= price * _count, "Not enough ether to purchase NFTs.");

        // Mint the specified number of NFTs to the sender's address.
        for (uint i = 0; i < _count; i++) {
            string memory metadata = generateMetadata(nextId + i);
            _mintSingleNft(msg.sender, metadata);
        }
    }

    // Function to mint a single NFT ticket with specified metadata.
    function _mintSingleNft(address _wAddress, string memory _tokenURI) private {
        // Check for potential token indexing issues.
        require(totalSupply() == _tokenIds.current(), "Indexing has broken down!");

        // Get the new token ID, mint the NFT, and set its metadata.
        uint newTokenID = _tokenIds.current();
        _safeMint(_wAddress, newTokenID);
        _setTokenURI(newTokenID, _tokenURI);
        _tokenIds.increment();
    }

    // Function to update the price of a single NFT.
    function updatePrice(uint _newPrice) public onlyOwner {
        price = _newPrice;
    }

    // Function to withdraw ether from the contract.
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        // Transfer the contract's balance to the owner.
        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    // Function to get the list of token IDs owned by a specific address.
    function tokensOfOwner(address _owner) external view returns (uint[] memory) {
        // Get the token count owned by the specified address.
        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint256[](tokenCount);

        // Populate the array with owned token IDs.
        for (uint i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    // The following functions are overrides required by Solidity.

    // Override the _beforeTokenTransfer function to include ERC721Enumerable behavior.
    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        if (balanceOf(to) > 0) {
            require(to == owner() || canMintMultiple[to], "Not authorized to hold more than one ticket");
        }
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }


    // Override the _burn function to include ERC721URIStorage behavior.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    // Override the tokenURI function to include ERC721URIStorage behavior.
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // Override the supportsInterface function to include ERC721Enumerable behavior.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}


