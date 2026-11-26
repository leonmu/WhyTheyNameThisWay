-- Word difficulty levels.
-- 1 = Basic (everyday English), 2 = Intermediate. Anything not listed = 3 (Advanced).
-- Whole names (Stormwind, Lucifron...) are not listed, so they always count as Advanced.
-- Move words between the lists to match your own level!
local ADDON, ns = ...
local L = {}
ns.LEVEL = L

local BASIC = [[
wolf bear cat dog rat bat owl eagle hawk snake fish shark crab turtle spider lion tiger
deer goat pig hog horse ram worm ghost giant king queen prince princess lord lady guard
soldier warrior hunter knight priest monk witch pirate thief cook butcher miner digger
captain young adult old big huge small red black white green blue gold silver iron steel
copper fire flame ice frost snow sand mud rock stone cliff cave river lake forest wood
jungle mountain hill coast shore storm wind thunder shadow dead ring belt boots gloves
shirt pants trousers hat sword axe hammer bow knife shield hood potion bread ale camp
spark dust hungry starving spotted striped plains desert strike kick shout cry fear rage
heal charge strength spirit blessing curse chain plate leather wool silk light heavy
dark deep fireball lightning bolt cliff trader banker mayor messenger servant prisoner
defender protector guardian archer emperor dawn dusk mail rifle magic hand leg king
]]

local INTERMEDIATE = [[
dagger cloak cape robe vest tunic helm gauntlet bracer bracers leggings sandals slippers
mace club staff wand rod spear crossbow musket pendant amulet charm trophy token pouch
satchel rucksack flask elixir tonic shard rune essence venom fang talon tusk scale hide
pelt ingot tin bronze linen swamp marsh valley canyon crater ridge peak summit glade grove
harbor isle cove ruins tomb crypt keep citadel spire cathedral monastery lair den burrow
outpost twilight gloom doom dread grim sorrow haunted cursed ancient scarlet crimson
emerald jade ivory azure plague blight scavenger bandit smuggler poacher mercenary assassin
outlaw rogue traitor inmate minion merchant vendor tailor blacksmith herbalist alchemist
physician surgeon sheriff deputy baron duke count ambassador courier scout ranger tracker
trapper sentry champion commander lieutenant chieftain warlord overlord apprentice novice
disciple cleric priestess paladin crusader gladiator shaman sorcerer conjurer illusionist
enchanter mystic oracle seer necromancer warlock zombie skeleton mummy demon imp phantom
troll ogre centaur drake whelp serpent viper cobra python scorpion beetle wasp hornet
alligator hyena panther leopard jaguar lynx cougar gorilla ape grizzly vulture eel slime
ooze sludge golem rotting decaying infected poisonous toxic venomous furious enraged savage
vicious feral rabid diseased crazed twisted corrupted restless tormented howling growling
snarling wailing moaning rusty worn cracked battered rough sturdy polished fine thick
padded reinforced enchanted frostbolt blink vanish backstab taunt overpower renew banish
purge summon conjure mend drain shield barrier aura seal totem sting fury vengeance
agility intellect stamina boulder ember lava magma void mana hound stew loaf biscuit
quiver scroll bandage tower stable steward magistrate marshal emissary herald chancellor
regent archmage pickpocket deserter buccaneer prospector foreman laborer captive enforcer
henchman executioner interrogator innkeeper armorer weaponsmith tanner witchdoctor
gargoyle vampire hatchling cub pup runt alpha jerky mead grog ward fade wrath strider
prairie dune crag cyclone tempest bloom thistle mole moccasin adder tortoise condor stag
doe fawn elk gazelle locust tarantula sentinel crawler hare
valley orchard patch cemetery graveyard manor echo oasis post landing dock pier port mill
lumber meadow ranch estate shrine altar sanctuary refuge retreat hideout fort fortress
barracks lookout plateau stream creek falls tunnel wreck hut tavern square district quarter
plaza chamber hall vault throne rise canal edge point stand watch mist logging brew
]]

for w in BASIC:gmatch("%S+") do L[w] = 1 end
for w in INTERMEDIATE:gmatch("%S+") do L[w] = L[w] or 2 end
