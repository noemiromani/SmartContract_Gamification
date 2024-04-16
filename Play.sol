// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract Play {
	event Log(address sender, uint value);
	address private deployer = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

	struct Player {
		string nickname;
		address walletAddress;
		uint total_score;
		bool subscription_fee;
	}
	
	uint total_Score = 0; 
	mapping(address => uint) public balance_of;

	struct Trip {
		address player_walletAddress;
		uint score;
	}

	struct Game {
        string _name;
        Player[] _players;
        uint startAt;
        uint expiresAt;
        bool spaceAvailable_completed;
        bool started;
		
		uint total_amount;
		uint first_prize;
		uint second_prize;
		uint third_prize;
    }
	uint private constant DURATION = 365 days;
    uint private constant START_AT_DEFAULT = 0;
    uint private constant EXPIRES_AT_DEFAULT = 0;
    uint private startAt;
    uint private expiresAt;
	uint private constant N_MIN_PLAYERS = 4;
	uint private constant N_MAX_PLAYERS = 10;
	uint private constant _FIRSTPRICEPERC_ = 50;
	uint private constant _SECONDPRICEPERC_ = 30;
	uint private constant _THIRDPRICEPERC_ = 50;
	uint private constant ETHER_TO_WEI = 1000000000000000000;


	mapping(string => bool) private is_Game;
    mapping(string => Game) public mapGamesbyName;
	mapping(string => bool) private firstPrizeGot;
	mapping(string => bool) private secondPrizeGot;
	mapping(string => bool) private thirdPrizeGot;
	mapping(string => uint) public FirstPrize;
	mapping(string => uint) public SecondPrize;
	mapping(string => uint) public ThirdPrize;




	
	mapping(string => mapping(address => Trip[])) public trips_by_Player;
	
	uint private constant MAX_NUMBER_OF_TRIPS = 10;



    mapping(string => mapping(address =>bool)) private isPlayer;
	mapping(address =>uint) private player_subscription;

	mapping(string => Player) private mapPlayersbyNickname;
	mapping(address => Player) private mapPlayersbyAddress;


	receive() external payable{
		emit Log(msg.sender, msg.value);
		player_subscription[msg.sender] = msg.value;
	}

	modifier GameExists(string memory _nameGame){//Game storage game = mapGamesbyName[_nameGame];
		require (is_Game[_nameGame], "The game you want to join does NOT exist");
		_;
	}

	modifier Game_Not_Exists(string memory _nameGame){
		require (!is_Game[_nameGame], "The game you want to create has been ALREADY created!");
		_;
	}

	modifier Game_Started(string memory _nameGame){
		Game storage game = mapGamesbyName[_nameGame];
		require (game.started, "Game Not started! You can't upload any trip!");
		_;
	}

	modifier Game_Not_Expired(string memory _nameGame){
		Game storage game = mapGamesbyName[_nameGame];
		require (block.timestamp < game.expiresAt, "Game expired!");
		_;
	}


	modifier Space_available(string memory _nameGame){
		Game storage game = mapGamesbyName[_nameGame];
		require (!game.spaceAvailable_completed, "You can't join this game, it's full!");
		_;
	}

	modifier UserTripsNumber(string memory _nameGame) {
		require (trips_by_Player[_nameGame][msg.sender].length < MAX_NUMBER_OF_TRIPS, "max number of trips already done!" );
		_;
	}
	
	// al momento dell'iscrizione ciascun player invia al contratto una fee amount, che la funzione su java prende in input (aggiungi anche come input in init_game e add_player) ,e va a definire il palyer amount versato;
	// quando il gioco inizia (n players del gioco raggiunto), ottieni i players del game, sommi gli amounts versati, che vanno a definire l'amount del gioco;
	// quando il gioco finisce risali all'amount del gioco, imponi le percentuali di divisioni in funzione della classifica, e invii quel amount ai specifici player;
	// FATTO --> struct player: aggiungi player_fee (valore assegnato in init_game e add_player) 
	// FATTO --> struct game: aggiungi game_amount (valore assegnato in add_player quando vincolo sul n di giocatori è soddisfatto)
	// --> const variables per percentuali di divisione del total amount.
	// --> come definisco la classifica finale in base al total amount aggiornato in ogni player?

	// --> Method invocabile quando si inizia un game, e quando, nonostante degli existing games, si vuole iniziare un nuovo game;
	//nickname
    function Init_Game(string calldata _nickNameInitPlayer, string calldata _nameGame) public  payable Game_Not_Exists(_nameGame){
		require (payable(msg.sender) != address(0), "invalid wallett address");
		require (msg.value != 0, "You have to pay your subscription fee");
        // Arrays e mappings are only allocated to storage
        // --> get a reference onto the struct from a mapping and go on;

		Player storage player = mapPlayersbyNickname[_nickNameInitPlayer];
		player.nickname = _nickNameInitPlayer;
		player.subscription_fee = true;
		player.walletAddress = msg.sender;


        Game storage game = mapGamesbyName[_nameGame];
        game._name = _nameGame;
		game._players.push(player);
        game.startAt = START_AT_DEFAULT;
        game.expiresAt = EXPIRES_AT_DEFAULT;
        game.spaceAvailable_completed = false;
        game.started = false;
		game.total_amount += msg.value;

		

		is_Game[_nameGame] = true;
        isPlayer[_nameGame][msg.sender] = true;
		player_subscription[msg.sender] += msg.value;
		
    }


    //JoinExistingGame
    //utente seleziona il nome del game al quale si vuole unire e lo passo come parametro
	// Game_Not_Started(_nameGame): NON LO CONSIDERERI UN VINCOLO PER add_player, lo considero per il load trip;
    function addPlayer(string calldata _nickName, string calldata _nameGame ) public payable Space_available(_nameGame) GameExists(_nameGame) {
        require (payable (msg.sender) != address(0), "invalid wallett address");
		require (msg.value != 0, "You have to pay your subscription fee");
    
        Game storage game = mapGamesbyName[_nameGame];
        require (!isPlayer[_nameGame][msg.sender], "You have already joined this game!");

		Player storage player = mapPlayersbyNickname[_nickName];
		player.nickname = _nickName;
		player.subscription_fee = true;
		player.walletAddress = msg.sender;
	
		game._players.push(player);
		game.total_amount += msg.value;

        isPlayer[_nameGame][msg.sender]= true;
		
	
		player_subscription[msg.sender] +=msg.value;
		
		// num_minimo_players = 4;
		// max_num_players = 10;

        if (game._players.length >= N_MIN_PLAYERS){
            game.startAt = block.timestamp;
            game.expiresAt = block.timestamp + DURATION;
            game.spaceAvailable_completed = false;
            game.started = true;
			game.first_prize = game.total_amount * 50 /100;
			game.second_prize = game.total_amount*30/100;
			game.third_prize = game.total_amount*20/100;
		
		}

		FirstPrize[_nameGame]= game.first_prize;
		SecondPrize[_nameGame]=game.second_prize;
		ThirdPrize[_nameGame] = game.third_prize;

		if (game._players.length == N_MAX_PLAYERS){
				game.spaceAvailable_completed = true;
		}
    }

	function get_Players_of_Game(string memory _nameGame) public view returns(Player[] memory){
		Game storage game = mapGamesbyName[_nameGame];
		Player[] storage players = game._players;
		return players;
	}


	//Game_Not_Expired(_nameGame): da inserire, lho tolto per prova
	function Retire_From_The_Game(string memory _reason, string memory _nameGame) public payable GameExists(_nameGame) returns (string memory){
		require (isPlayer[_nameGame][msg.sender], "You are NOT a player of that game!");
		Game storage game = mapGamesbyName[_nameGame];
		
		uint player_amount;
		for (uint i=0; i< game._players.length; i++){
			Player storage player = game._players[i];
			if (player.walletAddress == msg.sender){
				player_amount = player_subscription[msg.sender];
				payable(msg.sender).transfer(player_amount);
				balance_of[msg.sender]+= player_amount;
				//senza considerarae il fattore conversione, lofa automaticamente;
				delete game._players[i];
			}	
		}
		
		game.total_amount -= player_amount;
		game.first_prize = game.total_amount * 50 /100;
		game.second_prize = game.total_amount*30/100;
		game.third_prize = game.total_amount*20/100;
		isPlayer[_nameGame][msg.sender] = false;
		string memory retire_reason = _reason;
		return retire_reason;
	}

	function close_Game(string memory _nameGame) public payable GameExists(_nameGame){
		require (firstPrizeGot[_nameGame], "First price not yet assigned");
		require (secondPrizeGot[_nameGame], "Second price not yet assigned");
		require (thirdPrizeGot[_nameGame], "Third price not yet assigned");
		Game storage game = mapGamesbyName[_nameGame];
		require(block.timestamp >= game.expiresAt, "game NOT EXPIRED");
		if (game.total_amount > 0){
			payable(deployer).transfer(game.total_amount);
		}
		
	}
	
	// nel method:
	// 1) carico il trip in all_trips (vettore che mostra tutti i trip, di tutti i players)
	// 2) inserisco il trip nel mapping, cosi da caricarlo poi in playerTrips (vettore che contiene solo i trip dello specifico player)
	//IN QUESTO MODO, I METHODS 'set_TripToPlayer()' E 'getUserTrips(address _walletAddress)' NON MI SERVONO PIU'.
	//GameExists(_nameGame)

	//modifier con timestamp per trip non uguali da inserire;
	//INFO SENSIBILI: string memory _destinazione, string memory _timestamp;
	function load_Trip( uint _score, string memory _nameGame) public GameExists(_nameGame) UserTripsNumber(_nameGame) Game_Started(_nameGame) Game_Not_Expired(_nameGame){
		require (isPlayer[_nameGame][msg.sender], "You are NOT a player of that game!");

		Game storage game = mapGamesbyName[_nameGame];
		for (uint i = 0; i < game._players.length; i ++){
			Player storage player = game._players[i];
			if (player.walletAddress == msg.sender){
				player.total_score += _score;
			}
		}

		
		trips_by_Player[_nameGame][msg.sender].push(Trip({
			player_walletAddress : msg.sender,
			score : _score
		}));
		
	}
	
	
	function FirstPlayer(string calldata _nameGame) public view returns (string memory , uint )  {
		Game memory game = mapGamesbyName[_nameGame];
		Player memory firstPlayer = game._players[0];
		//require (block.timestamp > game.expiresAt, "Game Not ended!");

		string memory firstplayerusername;
		uint score;

		for (uint i= 1; i<game._players.length;i++){
			if (game._players[i].total_score > firstPlayer.total_score ){
				firstPlayer = game._players[i];
			}
		}

		firstplayerusername = firstPlayer.nickname;
		score = firstPlayer.total_score;

		return(firstplayerusername, score);
	}
	
	function SecondPlace(string calldata _nameGame) public view returns (string memory, uint)  {
		Game memory game = mapGamesbyName[_nameGame];
		//require (block.timestamp > game.expiresAt, "Game Not ended!");
		Player[] memory players = new Player[](game._players.length);

		(string memory nickname,)= FirstPlayer(_nameGame);
		Player memory firstPlayer = mapPlayersbyNickname[nickname];

		uint j = 0;
		for (uint i =0; i<game._players.length;i++){
			if (game._players[i].walletAddress != firstPlayer.walletAddress){
				players[j] = game._players[i];
				j++;
			}
		}


		Player memory secondPlayer = players[0];
		string memory secondPlayerusername;
		uint score;

		for (uint i= 1; i<players.length;i++){
			if (players[i].total_score > secondPlayer.total_score){
				secondPlayer = players[i];
			}
		}
		secondPlayerusername = secondPlayer.nickname;
		score = secondPlayer.total_score;
		
		return (secondPlayerusername, score);
	}
		

		

	function ThirdPlace(string calldata _nameGame) public view returns (string memory, uint)  {
		Game memory game = mapGamesbyName[_nameGame];
		//require (block.timestamp > game.expiresAt, "Game Not ended!");
		Player[] memory players = new Player[](game._players.length);

		(string memory nickname,)= FirstPlayer(_nameGame);
		Player memory firstPlayer = mapPlayersbyNickname[nickname];

		(string memory _nickname,)= SecondPlace(_nameGame);
		Player memory secondPlayer = mapPlayersbyNickname[_nickname];

		uint j = 0;
		for (uint i =0; i<game._players.length;i++){
			if (game._players[i].walletAddress != firstPlayer.walletAddress && game._players[i].walletAddress != secondPlayer.walletAddress){
				players[j] = game._players[i];
				j++;
			}
		}

		Player memory thirdPlayer = players[0];
		string memory thirdPlayerusername;
		uint score;

		for (uint i= 1; i<players.length;i++){
			if (players[i].total_score > thirdPlayer.total_score){
				thirdPlayer = players[i];
			}
		}
		thirdPlayerusername = thirdPlayer.nickname;
		score = thirdPlayer.total_score;

		return(thirdPlayerusername, score);
	}
	

	function sendPrize(string calldata _nameGame) public payable returns (uint game_amount) {
		Game storage game = mapGamesbyName[_nameGame];
		require (block.timestamp > game.expiresAt, "Game Not ended!");

		//mapPlayersbyNickname
		(string memory nickname,)= FirstPlayer(_nameGame);
		Player memory firstPlayer = mapPlayersbyNickname[nickname];

		(string memory _nickname,)= SecondPlace(_nameGame);
		Player memory secondPlayer = mapPlayersbyNickname[_nickname];

		(string memory _nickname_,)= ThirdPlace(_nameGame);
		Player memory thirdPlayer = mapPlayersbyNickname[_nickname_];

		
		//Al momento dell'iscrizione invio gli ether, e li salva automaticamente in wei;
		// --> qui non serve il fattore di comversione;
		// --> da Java: in input manderò wei;
		// --> da Contratto: traferisco wei;
		// io devo sapere a quanti ether corrispondono gli wei che trasferisco al contratto;
		// io devo sapere a quante ether corrispondo gli wei che ricevo da contratto;

		payable(firstPlayer.walletAddress).transfer(game.first_prize);
		firstPrizeGot[_nameGame] = true;
		balance_of[firstPlayer.walletAddress] += game.first_prize;

		payable(secondPlayer.walletAddress).transfer(game.second_prize);
		secondPrizeGot[_nameGame] = true;
		balance_of[secondPlayer.walletAddress] += game.second_prize;

		payable(thirdPlayer.walletAddress).transfer(game.third_prize);
		thirdPrizeGot[_nameGame] = true;
		balance_of[thirdPlayer.walletAddress] += game.third_prize;

		game_amount = game.total_amount - game.first_prize - game.second_prize - game.third_prize;
		game.total_amount = game_amount;
		balance_of[address(this)] -= game_amount;

		return game_amount;
	}
}






    
            
		


       
        
        





		
        



