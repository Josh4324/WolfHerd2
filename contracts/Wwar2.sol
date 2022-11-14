// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./Whitelist.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract WarETrunk is ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    /**
     * @dev _baseTokenURI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    string _baseTokenURI;
    address public marketAddress;

    constructor(string memory baseURI, address market)
        ERC721("WarETrunk", "WWT")
    {
        _baseTokenURI = baseURI;
        marketAddress = market;
    }

    function mint() public onlyOwner {
        uint256 newTokenId = tokenIds.current();
        _mint(msg.sender, newTokenId);
        tokenIds.increment();
        approve(marketAddress, newTokenId);
    }

    function mintMany(uint256 num) external onlyOwner {
        for (uint256 i = 0; i < num; i++) {
            mint();
        }
    }

    /**
     * @dev _baseURI overides the Openzeppelin's ERC721 implementation which by default
     * returned an empty string for the baseURI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        string memory t = string(
            abi.encodePacked(Strings.toString(tokenId), ".json")
        );
        return
            bytes(_baseTokenURI).length > 0
                ? string(abi.encodePacked(_baseTokenURI, t))
                : "";
    }

    function setBaseURI(string memory val) public onlyOwner {
        _baseTokenURI = val;
    }
}
