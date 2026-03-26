local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROOT = getgenv and getgenv() or _G
ROOT.Batata = ROOT.Batata or {}
_G.Batata = ROOT.Batata

local Batata = ROOT.Batata
Batata.Remotes = Batata.Remotes or {}

if Batata.Remotes._initialized == true and Batata.Remotes.Folder then
    return Batata.Remotes
end

local okRemotesFolder, remotesFolder = pcall(function()
    return ReplicatedStorage:WaitForChild("Remotes")
end)

if not okRemotesFolder or remotesFolder == nil then
    error("pasta ReplicatedStorage.Remotes ausente")
end

-- true  = remote essencial; espera ele existir com WaitForChild
-- false = remote opcional; tenta pegar com FindFirstChild
local REMOTE_CATALOG = {
    Core = {
        DataUpdated = {
            Wait = true,
            Description = "Atualizacao principal dos dados do jogador no cliente.",
        },
        GetPlayerData = {
            Wait = false,
            Description = "Consulta snapshot completo ou parcial dos dados do jogador.",
        },
        Error = {
            Wait = false,
            Description = "Retorno de erro do servidor para acoes invalidas ou bloqueadas.",
        },
        DataReset = {
            Wait = false,
            Description = "Evento de reset dos dados.",
        },
        UpdateSettings = {
            Wait = false,
            Description = "Atualiza configuracoes do jogador no servidor.",
        },
        WelcomeBack = {
            Wait = false,
            Description = "Evento de retorno de sessao ou offline progress.",
        },
        PlayerIdled = {
            Wait = false,
            Description = "Informa estado idle do jogador.",
        },
    },
    Click = {
        PerformClick = {
            Wait = true,
            Description = "Clique principal do jogo.",
        },
        ClickResult = {
            Wait = false,
            Description = "Resultado do clique.",
        },
        PurchaseClickUpgrade = {
            Wait = false,
            Description = "Compra upgrade normal de clique.",
        },
        GetUpgradeCost = {
            Wait = false,
            Description = "Consulta custo atual de upgrade normal.",
        },
        PurchaseDigUpgrade = {
            Wait = false,
            Description = "Compra upgrade do sistema de dig.",
        },
    },
    Generators = {
        PurchaseGenerator = {
            Wait = false,
            Description = "Compra gerador.",
        },
        DeleteGenerator = {
            Wait = false,
            Description = "Remove gerador.",
        },
        GetGeneratorCost = {
            Wait = false,
            Description = "Consulta custo atual de gerador.",
        },
        PurchaseGeneratorSlot = {
            Wait = false,
            Description = "Compra slot extra de geradores.",
        },
    },
    Prestige = {
        PerformPrestige = {
            Wait = true,
            Description = "Executa prestige.",
        },
        PrestigeComplete = {
            Wait = false,
            Description = "Confirma prestige concluido.",
        },
        GetPotentialPrestigePoints = {
            Wait = false,
            Description = "Consulta PP potencial do prestige.",
        },
        PurchasePrestigeUpgrade = {
            Wait = false,
            Description = "Compra upgrade com moeda de prestige.",
        },
        GetPrestigeUpgradeCost = {
            Wait = false,
            Description = "Consulta custo de upgrade de prestige.",
        },
        EquipPotato = {
            Wait = false,
            Description = "Equipa batata antes/depois do prestige.",
        },
    },
    Ascension = {
        PerformAscension = {
            Wait = true,
            Description = "Executa ascensao.",
        },
        GetAscensionInfo = {
            Wait = false,
            Description = "Consulta custo e informacoes da ascensao.",
        },
        AscensionComplete = {
            Wait = false,
            Description = "Confirma ascensao concluida.",
        },
    },
    Sell = {
        SellPotatoes = {
            Wait = false,
            Description = "Vende batatas comuns.",
        },
        SellGoldenPotatoes = {
            Wait = false,
            Description = "Vende batatas douradas.",
        },
        SellAllPotatoes = {
            Wait = false,
            Description = "Vende todas as batatas comuns.",
        },
        SellAllGoldenPotatoes = {
            Wait = false,
            Description = "Vende todas as batatas douradas.",
        },
        SellComplete = {
            Wait = false,
            Description = "Confirma venda concluida.",
        },
        AutoSellTriggered = {
            Wait = false,
            Description = "Indica autosell disparado pelo jogo.",
        },
        UpdateAutoSellSettings = {
            Wait = false,
            Description = "Atualiza filtros do autosell interno do jogo.",
        },
    },
    Fusion = {
        FusePotatoes = {
            Wait = false,
            Description = "Funde batatas.",
        },
        FusionResult = {
            Wait = false,
            Description = "Resultado da fusao.",
        },
        DissolvePotatoes = {
            Wait = false,
            Description = "Dissolve batatas.",
        },
        DissolveResult = {
            Wait = false,
            Description = "Resultado da dissolucao.",
        },
    },
    Genetics = {
        GeneticsRollSlot = {
            Wait = false,
            Description = "Rola genetics em um slot.",
        },
        GeneticsRollAll = {
            Wait = false,
            Description = "Rola genetics em varios slots.",
        },
        GeneticsResult = {
            Wait = false,
            Description = "Resultado do genetics.",
        },
        GeneticsUnlockSlot = {
            Wait = false,
            Description = "Desbloqueia slot de genetics.",
        },
    },
    Potions = {
        UsePotion = {
            Wait = false,
            Description = "Usa pocao do inventario.",
        },
        PotionBuffUpdated = {
            Wait = false,
            Description = "Atualizacao dos buffs ativos de pocao.",
        },
        ActivateFreeBoost = {
            Wait = false,
            Description = "Ativa boost gratis.",
        },
        ActivateFreeGlobalBoost = {
            Wait = false,
            Description = "Ativa boost global gratis.",
        },
        ActivateLeaderboardFreeGlobalBoost = {
            Wait = false,
            Description = "Ativa boost gratis ligado a leaderboard.",
        },
        CheckLeaderboardBoostEligibility = {
            Wait = false,
            Description = "Checa elegibilidade para boost de leaderboard.",
        },
        GetActiveGlobalBoosts = {
            Wait = false,
            Description = "Consulta boosts globais ativos.",
        },
        GetActiveServerBoosts = {
            Wait = false,
            Description = "Consulta boosts ativos no servidor.",
        },
        GlobalBoostActivated = {
            Wait = false,
            Description = "Confirma boost global ativado.",
        },
        GlobalBoostsUpdated = {
            Wait = false,
            Description = "Atualiza boosts globais.",
        },
        ServerBoostActivated = {
            Wait = false,
            Description = "Confirma boost de servidor ativado.",
        },
        ServerBoostsUpdated = {
            Wait = false,
            Description = "Atualiza boosts de servidor.",
        },
        LeaderboardFreeBoostUsed = {
            Wait = false,
            Description = "Indica boost gratis usado.",
        },
        ClaimOfflineBoostBonus = {
            Wait = false,
            Description = "Resgata bonus offline.",
        },
        RefreshSocialBonuses = {
            Wait = false,
            Description = "Recalcula bonus sociais.",
        },
    },
    Shop = {
        GetShopRotation = {
            Wait = false,
            Description = "Consulta rotacao atual da loja.",
        },
        ShopRotationUpdated = {
            Wait = false,
            Description = "Atualizacao da rotacao da loja.",
        },
        PurchaseShopPotato = {
            Wait = false,
            Description = "Compra item da loja rotativa.",
        },
        GetPremiumShop = {
            Wait = false,
            Description = "Consulta loja premium.",
        },
        PremiumShopUpdated = {
            Wait = false,
            Description = "Atualiza loja premium.",
        },
        PurchasePremiumItem = {
            Wait = false,
            Description = "Compra item premium.",
        },
        SetPendingPremiumItem = {
            Wait = false,
            Description = "Define item premium pendente.",
        },
        GetSeasonalShop = {
            Wait = false,
            Description = "Consulta loja sazonal.",
        },
        SeasonalShopUpdated = {
            Wait = false,
            Description = "Atualiza loja sazonal.",
        },
        PurchaseSeasonalItem = {
            Wait = false,
            Description = "Compra item sazonal.",
        },
        HotDealAvailable = {
            Wait = false,
            Description = "Oferta especial disponivel.",
        },
        HotDealExpired = {
            Wait = false,
            Description = "Oferta especial expirada.",
        },
        HotDealPurchased = {
            Wait = false,
            Description = "Confirma compra de hot deal.",
        },
        PurchaseHotDeal = {
            Wait = false,
            Description = "Compra hot deal.",
        },
    },
    Dig = {
        DigSquare = {
            Wait = false,
            Description = "Escava um tile.",
        },
        DigStaminaUpdate = {
            Wait = false,
            Description = "Atualizacao da stamina do dig.",
        },
        DigRoundInfo = {
            Wait = false,
            Description = "Informacoes da rodada e tiles com premio.",
        },
        DigResult = {
            Wait = false,
            Description = "Resultado da escavacao.",
        },
        DigStartRound = {
            Wait = false,
            Description = "Inicia rodada do dig.",
        },
    },
    Rewards = {
        OpenMysteryBox = {
            Wait = false,
            Description = "Abre uma mystery box.",
        },
        OpenMultipleMysteryBoxes = {
            Wait = false,
            Description = "Abre varias mystery boxes.",
        },
        MysteryBoxResult = {
            Wait = false,
            Description = "Resultado de mystery box.",
        },
        MultipleMysteryBoxResult = {
            Wait = false,
            Description = "Resultado de varias mystery boxes.",
        },
        ClaimBossReward = {
            Wait = false,
            Description = "Resgata recompensa de boss.",
        },
        ClaimLoginStreak = {
            Wait = false,
            Description = "Resgata login streak.",
        },
        LoginStreakClaimed = {
            Wait = false,
            Description = "Confirma login streak resgatado.",
        },
        SessionRewardGranted = {
            Wait = false,
            Description = "Recompensa de sessao concedida.",
        },
        SessionRewardsReset = {
            Wait = false,
            Description = "Reset das recompensas de sessao.",
        },
    },
    Codes = {
        RedeemCode = {
            Wait = false,
            Description = "Tenta resgatar codigo.",
        },
        CodeRedeemed = {
            Wait = false,
            Description = "Confirma codigo resgatado.",
        },
    },
    Inventory = {
        DeleteInventoryItem = {
            Wait = false,
            Description = "Deleta item generico do inventario.",
        },
        DeletePotatoItem = {
            Wait = false,
            Description = "Deleta batata do inventario.",
        },
        DeleteRelicItem = {
            Wait = false,
            Description = "Deleta reliquia.",
        },
        DeleteBackgroundItem = {
            Wait = false,
            Description = "Deleta background.",
        },
        EquipBackground = {
            Wait = false,
            Description = "Equipa background.",
        },
        TogglePotatoLock = {
            Wait = false,
            Description = "Trava ou destrava batata.",
        },
        ToggleRelicLock = {
            Wait = false,
            Description = "Trava ou destrava reliquia.",
        },
        ToggleBackgroundLock = {
            Wait = false,
            Description = "Trava ou destrava background.",
        },
        UpdateFavoriteStatus = {
            Wait = false,
            Description = "Atualiza favorito.",
        },
        UpdateGroupStatus = {
            Wait = false,
            Description = "Atualiza agrupamento.",
        },
        PurchasePotatoRoots = {
            Wait = false,
            Description = "Compra ligado a potato roots.",
        },
        PurchaseRootNode = {
            Wait = false,
            Description = "Compra node da arvore roots.",
        },
        RefundAllRoots = {
            Wait = false,
            Description = "Reseta ou refunda roots.",
        },
        ResetAllData = {
            Wait = false,
            Description = "Reseta todos os dados.",
        },
    },
    Discovery = {
        GoldenPotatoFound = {
            Wait = false,
            Description = "Notifica batata dourada encontrada.",
        },
        MagicPotatoFound = {
            Wait = false,
            Description = "Notifica batata magica encontrada.",
        },
        RarePotatoFound = {
            Wait = false,
            Description = "Notifica batata rara encontrada.",
        },
        CosmicPotatoFound = {
            Wait = false,
            Description = "Notifica batata cosmica encontrada.",
        },
    },
    Boss = {
        DamageBoss = {
            Wait = false,
            Description = "Causa dano no boss.",
        },
        GuildBossUpdate = {
            Wait = false,
            Description = "Atualiza boss da guild.",
        },
    },
    Guild = {
        CreateGuild = {
            Wait = false,
            Description = "Cria guild.",
        },
        DisbandGuild = {
            Wait = false,
            Description = "Desfaz guild.",
        },
        JoinGuild = {
            Wait = false,
            Description = "Entra em guild.",
        },
        LeaveGuild = {
            Wait = false,
            Description = "Sai da guild.",
        },
        SearchGuilds = {
            Wait = false,
            Description = "Busca guilds.",
        },
        GetGuildData = {
            Wait = false,
            Description = "Consulta dados da guild.",
        },
        GetGuildBuffs = {
            Wait = false,
            Description = "Consulta buffs da guild.",
        },
        GuildDataUpdated = {
            Wait = false,
            Description = "Atualiza dados da guild.",
        },
        InviteToGuild = {
            Wait = false,
            Description = "Convida jogador para guild.",
        },
        GuildInviteReceived = {
            Wait = false,
            Description = "Recebe convite de guild.",
        },
        RespondToGuildInvite = {
            Wait = false,
            Description = "Responde convite de guild.",
        },
        GuildInviteResponse = {
            Wait = false,
            Description = "Resposta do convite de guild.",
        },
        BanGuildMember = {
            Wait = false,
            Description = "Bane membro da guild.",
        },
        UnbanGuildMember = {
            Wait = false,
            Description = "Desbane membro da guild.",
        },
        RemoveGuildMember = {
            Wait = false,
            Description = "Remove membro da guild.",
        },
        PromoteGuildMember = {
            Wait = false,
            Description = "Promove membro da guild.",
        },
        DemoteGuildMember = {
            Wait = false,
            Description = "Rebaixa membro da guild.",
        },
        TransferGuildOwnership = {
            Wait = false,
            Description = "Transfere lideranca da guild.",
        },
        UpdateGuildName = {
            Wait = false,
            Description = "Atualiza nome da guild.",
        },
        UpdateGuildEmblem = {
            Wait = false,
            Description = "Atualiza emblema da guild.",
        },
        UpdateGuildJoinMode = {
            Wait = false,
            Description = "Atualiza modo de entrada da guild.",
        },
        DonateToGuild = {
            Wait = false,
            Description = "Doa para a guild.",
        },
        PurchaseGuildUpgrade = {
            Wait = false,
            Description = "Compra upgrade da guild.",
        },
        GuildBanned = {
            Wait = false,
            Description = "Notifica banimento da guild.",
        },
        GuildKicked = {
            Wait = false,
            Description = "Notifica expulsao da guild.",
        },
        GuildDisbanded = {
            Wait = false,
            Description = "Notifica dissolucao da guild.",
        },
    },
    Trade = {
        SendTradeRequest = {
            Wait = false,
            Description = "Envia pedido de troca.",
        },
        TradeRequestReceived = {
            Wait = false,
            Description = "Recebe pedido de troca.",
        },
        RespondToTrade = {
            Wait = false,
            Description = "Aceita ou recusa troca.",
        },
        TradeResult = {
            Wait = false,
            Description = "Resultado final da troca.",
        },
    },
    Leaderboard = {
        GetLeaderboard = {
            Wait = false,
            Description = "Consulta leaderboard geral.",
        },
        GetGlobalLeaderboard = {
            Wait = false,
            Description = "Consulta leaderboard global.",
        },
        GetServerLeaderboard = {
            Wait = false,
            Description = "Consulta leaderboard do servidor.",
        },
        GetServerPlayers = {
            Wait = false,
            Description = "Lista jogadores do servidor.",
        },
        ResolveUsername = {
            Wait = false,
            Description = "Resolve nome ou id de jogador.",
        },
    },
    Admin = {
        AdminBroadcast = {
            Wait = false,
            Description = "Broadcast administrativo.",
        },
        SubmitBroadcastReply = {
            Wait = false,
            Description = "Resposta a broadcast.",
        },
        AdminGift = {
            Wait = false,
            Description = "Presente administrativo.",
        },
    },
    Monetization = {
        InitiateGamepassGift = {
            Wait = false,
            Description = "Inicia presente de gamepass.",
        },
        GamepassGiftReceived = {
            Wait = false,
            Description = "Recebe presente de gamepass.",
        },
        GamepassGiftResult = {
            Wait = false,
            Description = "Resultado do presente de gamepass.",
        },
    },
}

local REMOTE_DEFINITIONS = {}
local REMOTE_METADATA = {}

for groupName, group in next, REMOTE_CATALOG do
    if type(group) == "table" then
        for remoteName, info in next, group do
            if type(info) == "table" then
                REMOTE_DEFINITIONS[remoteName] = info.Wait == true
                REMOTE_METADATA[remoteName] = {
                    Group = groupName,
                    Description = info.Description,
                    Wait = info.Wait == true,
                }
            end
        end
    end
end

local function getRemote(name, shouldWait)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    if shouldWait == true then
        local ok, remote = pcall(function()
            return remotesFolder:WaitForChild(name)
        end)
        return ok and remote or nil
    end

    local ok, remote = pcall(function()
        return remotesFolder:FindFirstChild(name)
    end)
    return ok and remote or nil
end

local function cacheRemote(name)
    local shouldWait = REMOTE_DEFINITIONS[name]
    if shouldWait == nil then
        return nil
    end

    local remote = getRemote(name, shouldWait)
    Batata.Remotes[name] = remote
    return remote
end

Batata.Remotes.Folder = remotesFolder
Batata.Remotes.Catalog = REMOTE_CATALOG
Batata.Remotes.Definitions = REMOTE_DEFINITIONS
Batata.Remotes.Metadata = REMOTE_METADATA

for remoteName in next, REMOTE_DEFINITIONS do
    cacheRemote(remoteName)
end

Batata.Remotes._initialized = true

function Batata.Remotes:Refresh(name)
    if type(name) == "string" and self.Definitions[name] ~= nil then
        return cacheRemote(name)
    end

    for remoteName in next, self.Definitions do
        cacheRemote(remoteName)
    end

    return self
end

function Batata.Remotes:Get(name)
    if type(name) ~= "string" then
        return nil
    end

    if self.Definitions[name] == nil then
        return self[name]
    end

    local cached = self[name]
    if cached ~= nil then
        return cached
    end

    return self:Refresh(name)
end

return Batata.Remotes
