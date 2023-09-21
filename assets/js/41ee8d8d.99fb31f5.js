"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[20202],{39667:e=>{e.exports=JSON.parse('{"functions":[{"name":"createConfig","desc":"Creates a new elo config.","params":[{"name":"config","desc":"Optional table with defaults","lua_type":"table?"}],"returns":[{"desc":"","lua_type":"EloConfig"}],"function_type":"static","source":{"line":51,"path":"src/elo/src/Shared/EloUtils.lua"}},{"name":"isEloConfig","desc":"Returns whether an object is an elo config","params":[{"name":"config","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"static","source":{"line":68,"path":"src/elo/src/Shared/EloUtils.lua"}},{"name":"getNewScores","desc":"Gets the new score for the player and opponent after a series of matches.","params":[{"name":"config","desc":"","lua_type":"EloConfig"},{"name":"playerRating","desc":"","lua_type":"number"},{"name":"opponentRating","desc":"","lua_type":"number"},{"name":"matchScores","desc":"0 for loss, 1 for win, 0.5 for draw.","lua_type":"{ number }"}],"returns":[{"desc":"playerRating","lua_type":"number"},{"desc":"opponentRating","lua_type":"number"}],"function_type":"static","source":{"line":82,"path":"src/elo/src/Shared/EloUtils.lua"}},{"name":"getNewScore","desc":"Gets the new score for the player after a series of matches.","params":[{"name":"config","desc":"","lua_type":"EloConfig"},{"name":"playerRating","desc":"","lua_type":"number"},{"name":"opponentRating","desc":"","lua_type":"number"},{"name":"matchScores","desc":"0 for loss, 1 for win, 0.5 for draw.","lua_type":"{ number }"}],"returns":[],"function_type":"static","source":{"line":101,"path":"src/elo/src/Shared/EloUtils.lua"}},{"name":"getExpected","desc":"Compute expected score for a player vs. player given the rating.\\n\\n:::info\\nA player\'s expected score is their probability of winning plus half their probability of drawing. Thus, an expected score of 0.75 could represent a 75% chance of winning, 25% chance of losing, and 0% chance of drawing\\n:::","params":[{"name":"config","desc":"","lua_type":"EloConfig"},{"name":"playerRating","desc":"","lua_type":"number"},{"name":"opponentRating","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"static","source":{"line":122,"path":"src/elo/src/Shared/EloUtils.lua"}},{"name":"getScoreAdjustment","desc":"Gets the score adjustment for a given player\'s base.","params":[{"name":"config","desc":"","lua_type":"EloConfig"},{"name":"playerRating","desc":"","lua_type":"number"},{"name":"opponentRating","desc":"","lua_type":"number"},{"name":"matchScores","desc":"0 for loss, 1 for win, 0.5 for draw.","lua_type":"{ number }"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"static","source":{"line":140,"path":"src/elo/src/Shared/EloUtils.lua"}},{"name":"fromOpponentPerspective","desc":"Flips the scores for the opponent","params":[{"name":"matchScores","desc":"0 for loss, 1 for win, 0.5 for draw.","lua_type":"{ number }"}],"returns":[{"desc":"","lua_type":"{ number }"}],"function_type":"static","source":{"line":163,"path":"src/elo/src/Shared/EloUtils.lua"}},{"name":"standardKFactorFormula","desc":"Standard kfactor formula for use in the elo config.","params":[{"name":"rating","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"static","source":{"line":181,"path":"src/elo/src/Shared/EloUtils.lua"}},{"name":"extractKFactor","desc":"Computes the kfactor for the given player from the rating","params":[{"name":"config","desc":"","lua_type":"EloConfig"},{"name":"rating","desc":"","lua_type":"number"}],"returns":[{"desc":"","lua_type":"number"}],"function_type":"static","source":{"line":198,"path":"src/elo/src/Shared/EloUtils.lua"}}],"properties":[],"types":[{"name":"EloConfig","desc":"","fields":[{"name":"factor","lua_type":"number","desc":""},{"name":"kfactor","lua_type":"number | function","desc":""},{"name":"initial","lua_type":"number","desc":""},{"name":"ratingFloor","lua_type":"number","desc":""}],"source":{"line":45,"path":"src/elo/src/Shared/EloUtils.lua"}}],"name":"EloUtils","desc":"Utilities to compute elo scores for players\\n\\n```lua\\nlocal config = EloUtils.createConfig()\\n\\nlocal playerRating = 1400\\nlocal opponentRating = 1800\\n\\n-- Update rating!\\nplayerRating, opponentRating = EloUtils.getNewScores(\\n\\tconfig,\\n\\tplayerRating,\\n\\topponentRating,\\n\\t{\\n\\t\\tEloUtils.Scores.WIN;\\n\\t})\\n\\n-- New rankings!\\nprint(playerRating, opponentRating)\\n```","source":{"line":24,"path":"src/elo/src/Shared/EloUtils.lua"}}')}}]);