// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import './token.sol';
import "hardhat/console.sol";


contract TokenExchange is Ownable {
    string public exchange_name = 'Harambe Ex';

    address tokenAddr = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // TODO: paste token contract address here
    Token public token = Token(tokenAddr);                                

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    mapping(address => uint) private lps; 
     
    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;                     

    // liquidity rewards
    uint private swap_fee_numerator = 0;                // TODO Part 5: Set liquidity providers' returns.
    uint private swap_fee_denominator = 0;

    // Constant: x * y = k
    uint private k;

    uint total_lp = 0;

    constructor() {}
    //receive() external payable {}
    

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        onlyOwner
    {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(index < lp_providers.length, "specified index is larger than the number of lps");
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }
    // HELPER FUNCTIONS
    
    function getExchangeRate() public view returns(uint, uint) {
        console.log("getting exchange rate");
        return (token.balanceOf(address(this)), address(this).balance);
    }
    
    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    
    /* ========================= Liquidity Provider Functions =========================  */ 

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate) 
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        

        //check to see exchange rate is in the right bounds
        require(token.balanceOf(address(this))/address(this).balance >= min_exchange_rate);
        require(token.balanceOf(address(this))/address(this).balance <= max_exchange_rate);
        
        //get tokens from wallet
        uint tokens_added =  msg.value * token.balanceOf(address(this))/address(this).balance;

        require(tokens_added <= token.balanceOf(address(this)));
        require(msg.value <= msg.sender.balance);

        //transfer ETH/Token 
        token.transferFrom(msg.sender,address(this),tokens_added);
        payable(address(this)).transfer(msg.value);
        console.log(msg.value);
        console.log("transfered tokens and eth");

        //update lp tokens
        uint add_LP_amount = msg.value/address(this).balance * total_lp;
        total_lp = total_lp + add_LP_amount;
        //lp ownership
        if (lps[msg.sender] == 0){
            lp_providers.push(msg.sender);
        }
        
        lps[msg.sender] = lps[msg.sender] + add_LP_amount;
        console.log(lps[msg.sender]);
        console.log("updated lp tokens");
        //update reserves
        eth_reserves += msg.value;
        token_reserves += tokens_added;

        //update k
        //assert
        k = token_reserves * eth_reserves;
        console.log("finished add");
    }

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate)
        public 
        payable
    {
        /******* TODO: Implement this function *******/

        assert (amountETH <= address(this).balance);
        // convert amountETH to LPs 
        uint remove_LP_amount = amountETH/address(this).balance; 

        require(token.balanceOf(address(this))/address(this).balance >= min_exchange_rate);
        require(token.balanceOf(address(this))/address(this).balance <= max_exchange_rate);

        uint remove_Token_amount = remove_LP_amount/total_lp * token.balanceOf(address(this));
        assert (remove_Token_amount <= token.balanceOf(address(msg.sender)));
        

        assert (remove_LP_amount <= lps[msg.sender]);
        assert (amountETH <= msg.sender.balance);
        
        total_lp = total_lp - remove_LP_amount;

        eth_reserves -= amountETH;
        token_reserves -= remove_Token_amount;

        //update k
        k = token_reserves * eth_reserves;
        
        token.transferFrom(address(this),msg.sender,remove_Token_amount);
        payable(msg.sender).transfer(msg.value);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        require(token.balanceOf(address(this))/address(this).balance >= min_exchange_rate);
        require(token.balanceOf(address(this))/address(this).balance <= max_exchange_rate);

        /******* TODO: Implement this function *******/
        uint remove_LP_amount = lps[msg.sender];

        

        uint remove_ETH_amount = remove_LP_amount / total_lp * address(this).balance;
        uint remove_TOKEN_amount = remove_LP_amount / total_lp * token.balanceOf(address(this));

        token.transferFrom(address(this),msg.sender,remove_TOKEN_amount);
        payable(address(this)).transfer(remove_ETH_amount);
    
    }
    /***  Define additional functions for liquidity fees here as needed ***/


    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
        external 
        payable
    {
        /******* TODO: Implement this function *******/

        uint amountETH = address(this).balance - k / (token.balanceOf(address(this)) + amountTokens);
        assert (amountTokens/amountETH <= max_exchange_rate); //check if need flip 

        token.transferFrom(msg.sender,address(this),amountTokens);
        payable(address(this)).transfer(msg.value);
        
        assert (address(this).balance * token.balanceOf(address(this)) == k);
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate)
        external
        payable 
    {
        /******* TODO: Implement this function *******/
        uint amountTokens = token.balanceOf(address(this)) - k / (address(this).balance + msg.value);
        assert (msg.value/amountTokens <= max_exchange_rate); //check if need flip 

        token.transferFrom(msg.sender,address(this),msg.value);
        payable(msg.sender).transfer(msg.value); //https://ethereum-blockchain-developer.com/2022-03-deposit-withdrawals/08-the-payable-modifier/

        assert (address(this).balance * token.balanceOf(address(this)) == k); //?

    }
}
