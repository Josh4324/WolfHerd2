//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Vault.sol";
import "./Busd.sol";
import "hardhat/console.sol";
import "./Whitelist.sol";

error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error ItemNotForSale(address nftAddress, uint256 tokenId);
error NotListed(address nftAddress, uint256 tokenId);
error AlreadyListed(address nftAddress, uint256 tokenId);
error NoProceeds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();

contract MARKETPLACE is Ownable {
    // LISITNG
    // BUY
    // UPDATE LISITING

    uint256 public counter = 0;
    BUSD internal tokenBUSD;
    Vault public vault;
    address public vaultAddress;
    // Whitelist contract instance
    Whitelist public whitelist;

    mapping(address => address) public Referral;

    // referral fee
    uint256 public constant referralFee = 2;

    // royalty fee
    uint256 public royaltyFee = 6;

    // boolean to keep track of _buyback status
    bool public _buyback = false;

    // _paused is used to pause the contract in case of an emergency
    bool public _paused = true;

    // boolean to keep track of whether presale started or not
    bool public presaleStarted = true;

    struct Listing {
        uint256 price;
        address owner;
        uint256 tokenId;
        bool sold;
        address nftaddress;
        uint256 listId;
    }

    constructor(
        address busd_addr,
        address _vault,
        address _whitelist_addr
    ) {
        tokenBUSD = BUSD(busd_addr);
        vault = Vault(_vault);
        vaultAddress = _vault;
        whitelist = Whitelist(_whitelist_addr);
    }

    modifier canBuyBack() {
        require(_buyback, "Buyback is not active");
        _;
    }

    modifier canPresale() {
        require(presaleStarted, "Presale has ended");
        _;
    }

    modifier onlyWhenNotPaused() {
        require(_paused == false, "Contract currently paused");
        _;
    }

    mapping(uint256 => Listing) ListItems;
    mapping(address => mapping(uint256 => Listing)) private TokenList;

    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    ) external onlyWhenNotPaused {
        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }

        require(
            IERC721(address(nftAddress)).ownerOf(tokenId) == msg.sender,
            "You do not have access to this NFT"
        );

        if (
            TokenList[nftAddress][tokenId].sold == false &&
            TokenList[nftAddress][tokenId].owner != address(0)
        ) {
            revert AlreadyListed(nftAddress, tokenId);
        }

        if (TokenList[nftAddress][tokenId].owner == address(0)) {
            ListItems[counter] = Listing(
                price,
                msg.sender,
                tokenId,
                false,
                nftAddress,
                counter
            );
            TokenList[nftAddress][tokenId] = Listing(
                price,
                msg.sender,
                tokenId,
                false,
                nftAddress,
                counter
            );

            counter++;
        } else {
            ListItems[TokenList[nftAddress][tokenId].listId].price = price;
            ListItems[TokenList[nftAddress][tokenId].listId].owner = msg.sender;
            ListItems[TokenList[nftAddress][tokenId].listId].sold = false;

            TokenList[nftAddress][tokenId].price = price;
            TokenList[nftAddress][tokenId].owner = msg.sender;
            TokenList[nftAddress][tokenId].sold = false;
        }
    }

    /* Returns all unsold List items */
    function fetchListItems() public view returns (Listing[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < counter; i++) {
            if (ListItems[i].sold == false) {
                itemCount += 1;
            }
        }

        Listing[] memory items = new Listing[](itemCount);

        for (uint256 i = 0; i < counter; i++) {
            if (ListItems[i].sold == false) {
                uint256 currentId = i;

                Listing storage currentItem = ListItems[currentId];
                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns all unsold List items */
    function fetchMyListItems() public view returns (Listing[] memory) {
        uint256 currentIndex = 0;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < counter; i++) {
            if (ListItems[i].owner == msg.sender) {
                itemCount += 1;
            }
        }

        Listing[] memory items = new Listing[](itemCount);

        for (uint256 i = 0; i < counter; i++) {
            if (ListItems[i].owner == msg.sender) {
                uint256 currentId = i;

                Listing storage currentItem = ListItems[currentId];
                items[currentIndex] = currentItem;

                currentIndex += 1;
            }
        }
        return items;
    }

    function buy(address nftAddress, uint256 tokenId) external {
        require(presaleStarted == false, "presale ongoing");
        require(
            tokenBUSD.balanceOf(msg.sender) >=
                TokenList[nftAddress][tokenId].price,
            "Not enough busd"
        ); //checks that enough busd

        uint256 royalTax = (TokenList[nftAddress][tokenId].price * royaltyFee) /
            100;
        uint256 amount = TokenList[nftAddress][tokenId].price - royalTax;

        uint256 Per = (TokenList[nftAddress][tokenId].price * referralFee) /
            100;
        uint256 actualPrice = TokenList[nftAddress][tokenId].price -
            (Per + royalTax);

        if (Referral[msg.sender] != address(0)) {
            require(
                tokenBUSD.transferFrom(
                    msg.sender,
                    TokenList[nftAddress][tokenId].owner,
                    actualPrice
                ),
                "An error occured, make sure you approve the contract"
            );
            require(
                tokenBUSD.transferFrom(msg.sender, Referral[msg.sender], Per),
                "An error occured, make sure you approve the contract"
            );
            require(
                tokenBUSD.transferFrom(msg.sender, vaultAddress, royalTax),
                "An error occured, make sure you approve the contract"
            );
        } else {
            require(
                tokenBUSD.transferFrom(
                    msg.sender,
                    address(ListItems[tokenId].owner),
                    amount
                ),
                "An error occured, make sure you approve the contract"
            );

            require(
                tokenBUSD.transferFrom(msg.sender, vaultAddress, royalTax),
                "An error occured, make sure you approve the contract"
            );
        }

        IERC721(address(nftAddress)).safeTransferFrom(
            TokenList[nftAddress][tokenId].owner,
            msg.sender,
            tokenId
        );

        ListItems[TokenList[nftAddress][tokenId].listId].owner = msg.sender;
        ListItems[TokenList[nftAddress][tokenId].listId].sold = true;

        TokenList[nftAddress][tokenId].owner = msg.sender;
        TokenList[nftAddress][tokenId].sold = true;
    }

    function presaleBuy(address nftAddress, uint256 tokenId)
        external
        canPresale
    {
        require(whitelist.whitelist(msg.sender), "no whitelist");
        require(
            tokenBUSD.balanceOf(msg.sender) >=
                TokenList[nftAddress][tokenId].price,
            "Not enough busd"
        ); //checks that enough busd

        uint256 royalTax = (TokenList[nftAddress][tokenId].price * royaltyFee) /
            100;
        uint256 amount = TokenList[nftAddress][tokenId].price - royalTax;

        uint256 Per = (TokenList[nftAddress][tokenId].price * referralFee) /
            100;
        uint256 actualPrice = TokenList[nftAddress][tokenId].price -
            (Per + royalTax);

        if (Referral[msg.sender] != address(0)) {
            require(
                tokenBUSD.transferFrom(
                    msg.sender,
                    TokenList[nftAddress][tokenId].owner,
                    actualPrice
                ),
                "An error occured, make sure you approve the contract"
            );
            require(
                tokenBUSD.transferFrom(msg.sender, Referral[msg.sender], Per),
                "An error occured, make sure you approve the contract"
            );
            require(
                tokenBUSD.transferFrom(msg.sender, vaultAddress, royalTax),
                "An error occured, make sure you approve the contract"
            );
        } else {
            require(
                tokenBUSD.transferFrom(
                    msg.sender,
                    address(ListItems[tokenId].owner),
                    amount
                ),
                "An error occured, make sure you approve the contract"
            );

            require(
                tokenBUSD.transferFrom(msg.sender, vaultAddress, royalTax),
                "An error occured, make sure you approve the contract"
            );
        }

        IERC721(address(nftAddress)).safeTransferFrom(
            TokenList[nftAddress][tokenId].owner,
            msg.sender,
            tokenId
        );

        ListItems[TokenList[nftAddress][tokenId].listId].owner = msg.sender;
        ListItems[TokenList[nftAddress][tokenId].listId].sold = true;

        TokenList[nftAddress][tokenId].owner = msg.sender;
        TokenList[nftAddress][tokenId].sold = true;
    }

    function cancelListing(address nftAddress, uint256 tokenId)
        external
        onlyWhenNotPaused
    {
        require(
            IERC721(address(nftAddress)).ownerOf(tokenId) == msg.sender,
            "You do not have access to this NFT"
        );

        ListItems[TokenList[nftAddress][tokenId].listId].sold = true;
        TokenList[nftAddress][tokenId].sold = true;
    }

    function endPresale() public onlyOwner {
        presaleStarted = false;
    }

    function setPaused(bool val) public onlyOwner {
        _paused = val;
    }

    function setRoyalTax(uint256 val) public onlyOwner {
        royaltyFee = val;
    }

    function setBuyBack(bool val) public onlyOwner {
        _buyback = val;
    }

    function buyBack(address nftAddress, uint256 tokenId) public canBuyBack {
        require(
            IERC721(address(nftAddress)).ownerOf(tokenId) == msg.sender,
            "You do not have access to this NFT"
        );
        require(
            tokenBUSD.balanceOf(address(this)) >=
                TokenList[nftAddress][tokenId].price,
            "Not enough busd"
        ); //checks that enough eth

        IERC721(address(nftAddress)).safeTransferFrom(
            TokenList[nftAddress][tokenId].owner,
            owner(),
            tokenId
        );

        ListItems[TokenList[nftAddress][tokenId].listId].owner = owner();
        ListItems[TokenList[nftAddress][tokenId].listId].sold = false;

        TokenList[nftAddress][tokenId].owner = owner();
        TokenList[nftAddress][tokenId].sold = false;

        require(
            tokenBUSD.transfer(
                msg.sender,
                TokenList[nftAddress][tokenId].price
            ),
            "An error occured, make sure you approve the contract"
        );
    }

    function getReferral(address user) public view returns (address) {
        return Referral[user];
    }

    function setReferral(address val) public {
        require(val != msg.sender, "you cant be your referral");
        Referral[msg.sender] = val;
    }
}
