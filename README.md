# VSRG Hub

Etterna's song wheel with your own Quaver, Qwilight and osu! libraries in it, dressed in your osu! skin.
(Formerly TriWheel.)

Only Etterna is needed. Quaver, Qwilight and osu! are optional: whichever of them you have adds its
songs (and, for osu! and Quaver, its skins); the ones you don't have are simply left out.

VSRG Hub finds them on any drive: osu! (stable) where its installer put it (Windows remembers where
osu!.exe is), in its usual folder or in an osu! folder at the top of a drive, Games or Program Files;
Quaver and Qwilight in any of your Steam libraries. If it still misses one, start `vsrghub.exe` with
`--osu "D:\path\to\osu!"` (or `--quaver`, `--qwilight`): a shortcut with that at the end of its target
works. osu!lazer keeps its maps in a form only lazer reads, so only osu!stable's songs are added.

Etterna is the game you play. When you press Play, VSRG Hub reads the songs already installed in your
Quaver and Qwilight folders, right where they are, and Etterna starts with them on its wheel next to your
Etterna packs:

- **A "Quaver" group**: every Quaver map set, played with Etterna's judging. Each song keeps its own
  background, banner and preview point from Quaver and is tagged **[Quaver]** under its title.
  4K maps get Etterna difficulty ratings (MSD) and count like any other 4K chart.
- **A "Qwilight" group** (plus a "Qwilight - <pack>" group for each pack folder): your Qwilight BMS
  bundles, read by Etterna's own BMS loader with their keysounds, stage files, banners and preview clips.
- **An "osu!" group**: your osu!mania beatmaps (4K and 7K), tagged **[osu!]**, rated with Etterna's MSD
  instead of star rating.
- **Your skins as noteskins**: every osu! skin with mania art becomes a noteskin ("osu!_<skin>") for 4K
  and 7K, and every Quaver skin becomes "quaver_<skin>" for 4K and 7K: the ones in Quaver's Skins
  folder and the ones Quaver downloaded from the Steam Workshop. They are drawn the way each game draws
  them:
  - osu!: each column's own width and the gaps between columns (ColumnWidth / ColumnSpacing), and the
    skin's LightingN flash and LightingL glow over the hit line.
  - Quaver: notes coloured by beat snap (ColorObjectsBySnapDistance, from separate pictures or a
    sprite sheet), notes and receptors turned per column, the gap between columns (NotePadding), note
    height (WidthForNoteHeightScale), receptors in front of the notes when the skin asks for it, the
    hit and hold lighting, the column lighting, and everything the skin doesn't set taken from its
    DefaultSkin (Bar, Arrow or Circle), as Quaver does.
  Hold ends are drawn the way osu! and Quaver draw them: osu!'s end image inside the hold, Quaver's
  centred on the hold's end with the body under its lower half, turned the way each game turns it (osu!
  uses the head image when a skin has no tail image), and the hold's body starts inside the head, behind
  it, as in osu!. The images come from skin.ini as osu! reads them (NoteImage#H, #L, #T; the first
  [Mania] section for a key count; a path that isn't in the skin draws nothing, as in osu!, and is noted
  in `vsrghub.log`). Many osu! skins draw the hold's end at the top of a very tall repeating body image
  (thousands of pixels): osu! draws that image from the hold's end, so its styled top is the end you
  see; VSRG Hub cuts that top off as the hold's end, at the size osu! draws it, and repeats the plain
  rest as the body. Etterna's own noteskins are left as Etterna draws them. When you change skins in osu!, VSRG Hub plays with that skin's notes next
  time, like osu! does. Pick any other one in VSRG Hub's options or in Etterna's Player Options; the
  pick is remembered.
- **Options like osu!** (Ctrl+O on the main menu or song select, or Options on the main menu): a panel that slides in from the left. As in gucci!mania, the skin for the interface and the
  notes for gameplay are chosen separately: "Interface skin" (any of your osu! skins, or the same one as
  osu!), "Notes (4K)" and "Notes (7K)". In play, the stage, judgments, combo, score and HP bar come from
  the skin whose notes you play with (notes from a Quaver skin, e.g. "Quaver maria", bring that skin's
  judgements, combo digits and score / accuracy digits, in the osu! look too: like Quaver, the pictures
  come from the skin's Judgements and Numbers folders, shared by 4K and 7K, at the sizes its skin.ini
  sets for the mode you play; a Quaver skin without its own digits shows plain numbers). Also scroll speed, scroll direction, and links to Etterna's own
  options. (On song select Etterna also uses Ctrl+O for practice mode; VSRG Hub undoes that and opens
  its options instead; practice mode is the Practice mod, see below.) Besides the skin and gameplay
  rows, the options have what any game has: VIDEO (display mode: windowed, fullscreen or borderless;
  resolution, from your monitor's modes; VSync; Apply display settings, which reloads the look with
  the song you had selected; Renderer, OpenGL or Direct3D, from the next start; FPS counter;
  background dim), PERFORMANCE (FPS limit in menus and while
  playing, exact or predictive limiting, and how much to slow down while another window is in front)
  and AUDIO (master, menu music and effects volume; audio offset, typeable). Scroll speed can be
  typed (C700, M650, 2.5x or just a number); rows with a value have < > to lower or raise it.
- **Five looks to choose from** (Options > Theme, Ctrl+O in any of them, or the launcher):
  - **osu!**: osu!'s screens (osu! stable), built from your osu! skin (below). VSRG Hub draws its own
    parts the modern way, rounded and coloured with soft shadows and animations: the main menu's pink
    cookie pulsing to the menu music with its visualizer, the coloured Play / Options / Exit buttons,
    the "now playing" box (previous / pause / next), the song panels (songs pink, groups blue, the
    selected one white) with the chart's MSD on a pill, the ranking rows, the options, lists and
    dialogs (rounded pills), the mods panel and the results (a rounded panel with coloured judgement
    chips, the life graph filled, a "full combo" pill, Watch replay as a pill, the pink back tab).
  - **osu!lazer**: osu!lazer's screens, with every feature of the osu! look: the toolbar along the top
    (settings, home, the key mode as lazer's rulesets, packs, collections, the music controller, your
    profile with your rating, and the clock with the time VSRG Hub has been running); the main menu's
    button bar through the logo (settings, play, browse = Etterna's pack downloader, exit; play opens
    back, solo and multi; P, S, M, D, O and Q work as in lazer); song select with lazer's slanted wedge
    (title, artist, length, BPM, notes, holds and mines, the MSD on a star pill in lazer's star
    colours, and Etterna's eight pattern ratings as lazer's detail bars), Local / Global / Preview tabs
    with the rate beside them, slanted score rows with their place, max combo, accuracy, score and a
    grade tab in lazer's grade colours, the search box with its match count, Sort / Group /
    Collection, the carousel with each song's picture and its difficulties opening under it, the
    footer (the pink Back, Mods, Random, Options and the mods that are on) and lazer's mod select in
    four columns; lazer's dialogs; and the results card with lazer's accuracy ring filling up round
    the grade, the score, the judgements in lazer's colours, beside the life graph, Til' Death's
    details and the hit offsets. Its text uses Nunito, a rounded font like lazer's.
  - **Quaver**: Quaver's screens: the top navigation bar, the map info strip with Mode / Group by /
    Sort by and search, the song list with each song's banner, the leaderboard with the chart's MSD for
    every pattern type and the rate, Quaver's modifiers dialog, Quaver's gameplay HUD (score, accuracy,
    combo, health bar, hit error bar, time) and Quaver's results with the hit deviance graph. Playing
    with a Quaver skin's notes, the HUD uses that skin's own judgements, score and combo digits and
    health bar, at the skin's sizes (a skin that hides its judgements hides them here too). The bottom
    bar works like Quaver's: Options, Modifiers, View Map (the selected chart scrolling with its preview
    and its density graph), Profile, Create Playlist, Random and Play. Clicking a song selects it and
    Enter plays it (also from the search box, as in Quaver); Esc closes the modifiers, map preview or
    profile without leaving song select. Right click a map for Quaver's map menu (play,
    favourite, add to a playlist, new playlist, view map); DOWNLOAD in the top bar is Etterna's pack
    downloader; quitting asks first. Difficulty numbers use Quaver's
    colours: cyan under 1, green under 2.5, light blue under 10, yellow under 20, red under 30, pink under
    40, violet under 50 and grey-white from 50 up.
  - **Til' Death** and **Rebirth**: Etterna's own themes, as they are. Ctrl+O there opens a small
    VSRG Hub menu drawn in that theme's own style, in sections like the osu! look's options: switch
    looks, the noteskin (each one shown playing the selected chart beside the list), the pointer (shown beside the list), 4K / 7K, scroll speed and
    direction (left / right change values), the timing (Etterna's judge J4 to Justice, osu!'s OD 0 to
    10, or Quaver's judgement windows), 7K thumb, Customize gameplay on or off, pausing, keybinds,
    video / performance / audio (the same rows as the osu! look), Etterna's own options and player
    options, and your play time for 4K, 7K and in total.
    On song select it also turns practice mode on or off, sets the long note mod (Full LN / Inverse,
    as in the other looks) and filters the songs by one of your osu! collections or Etterna
    playlists, or by pattern. While the menu is open it keeps the keyboard and mouse to itself.
    Alt + mouse wheel changes the volume there too.
  The pick is remembered for the next start. Switching looks keeps your key mode, the selected chart
  and your noteskin: the osu!, osu!lazer and Quaver looks open straight on song select with that chart picked,
  Til' Death and Rebirth pick it when you get to their song select. While Etterna starts or reloads for
  a look, the splash screen is that look's (osu!'s cookie, Quaver's logo) instead of Til' Death's name.
- **Your osu! collections**: on song select, Collections (a tab in the osu! look, a button in the
  Quaver look) lists the collections you made in osu!; picking one shows only its songs, "All songs"
  shows everything again.
- **Lists you can search**: themes, interface skins and noteskins open as a list (Enter or click on the
  option); type to filter it, arrows / mouse wheel to move, Enter or click to pick.
- **The rate follows everywhere**: changing the rate (click it: +0.05x, right click: -0.05x) updates the
  MSD at the top, in the pattern breakdown and on every song in the wheel.
- **The osu! interface, built from your osu! skin**: VSRG Hub draws osu!'s screens with the files of the
  skin selected in osu!, and draws nothing where your skin deliberately blanks something, just like osu!.
  - Main menu: the big cookie with Play / Multi / Options / Exit sliding out from behind it, your player
    card (Etterna rating in place of pp) and the song count, uptime and clock lines.
  - Song select: the song's background, the skin's songselect-top and songselect-bottom bars, the
    beatmap info lines (length, BPM, objects, keys, and Etterna's MSD where osu! shows star rating),
    Group / Sort and the search bar at the top right, the local ranking of your scores on the left, the
    carousel of songs with each song's background as a thumbnail, its hardest chart and MSD, your card in
    the middle and the cookie to play. (The carousel, buttons and panels are drawn by VSRG Hub rather than
    taken from the skin, since skin art often has osu!-only text written in; the skin still gives the
    backgrounds, the main menu background, the mod icons and everything in gameplay.) F1 (or the mods
    button) opens osu!'s mod select with the skin's mod icons (No Fail, Half Time, Double Time, Hidden,
    Fade In, Mirror, Random, Autoplay, Invert and Full LN, mapped to Etterna's options); start typing
    anywhere to search, as in osu!. Ctrl+R (or the random button) jumps to a random song; osu!'s F2
    can't be used, Etterna keeps it for reloading. The mode button switches between 4K and 7K without leaving the osu!
    look, and comes back to song select.
  - Gameplay: osu!mania's stage with the skin's stage art, columns spaced to the skin's column width,
    the skin's hit judgments at its ScorePosition, combo at its ComboPosition, score and accuracy in the
    skin's number font (overlap and all), the HP bar standing at the stage's edge and the active mods.
  - Results: the hit counts, max combo and accuracy where osu! writes them, the ranking graph with your
    life line, the full-combo stamp, the big grade (drawn behind the panels, so a big grade image never
    covers them), Etterna's hit-offset plot (below) and the skin's own back button.
  - When the skin has no song select buttons, VSRG Hub's back / mode / mods / random / options are
    flat labels on the bar (with their keys under them: F1 mods, Ctrl+R random, F3 beatmap options) that light up in the interface
    colour under the mouse, instead of boxes of their own.
  - The colour of the parts VSRG Hub draws itself (mode / mods / random / options, the play cookie,
    tabs and highlights) comes from your interface skin's own art instead of osu!'s strong pink;
    Options > Interface colour picks another one (osu! pink among them).
  - Click your player card on song select for your profile (Etterna's ratings per skillset, plays,
    hits, play time). F3 (beatmap options) also makes a new playlist with the selected chart.
  Settings, profiles and option screens are still Etterna's own (Til Death) underneath. Etterna's debug
  menu moves from F3 to F10 while VSRG Hub runs.
- **Keybinds, in every look**: Ctrl+K (or Keybinds in the options; in Til' Death and Rebirth, in
  VSRG Hub's Ctrl+O menu) lists every key worth knowing, by category (general, song select, gameplay,
  note keys, practice and replays, results, Customize gameplay, Etterna's tools), drawn in the look's
  own style: osu!'s options panel, Quaver's options dialog, Til' Death's and Rebirth's menus. VSRG Hub's
  own shortcuts (options, keybinds, pausing on / off, mods, random song, beatmap options, play from the
  preview, pause, skip the intro) and Etterna's note keys (of the mode being played), restart and rate
  keys can be changed there: Enter (or a click), then the new key; Delete puts the default back. A key
  that something else already uses where the shortcut works (Etterna's own keys, a note key, typing
  into the search) is refused with the reason; a key another shortcut has is swapped with it. VSRG Hub's
  are kept in `Save/VSRGHub/keys.ini`, Etterna's in its own key map (`Save/Keymaps.ini`). Keys are
  shown as your keyboard prints them.
- **Keys from a menu**: 4K / 7K is the "Keys" row in the options (Ctrl+O) and the mode button / MODE
  dropdown on song select, in every look.
- **Judge or osu! OD**: the options and Etterna's Player Options have a "Judge" row (J4 to Justice) and
  an "osu! OD" row (OD 0 to OD 10, with Etterna's windows scaled the way osu!mania's change with OD). Only one is in
  use at a time: changing one switches the other off. Played on an osu! OD, the accuracy in gameplay
  is osu!mania's (300g and 300 both count 100%, 200, 100 and 50 their share, a miss nothing); the
  results show the accuracy at J4 (what Etterna ranks by) with osu!'s beside it. Notes are still
  judged by Etterna (osu!'s own hold-note rules aren't copied).
- **Accuracy on other timings**: on the results of the osu! and Quaver looks, hover the accuracy for a
  small window, following the mouse, with what the play would be at J4, J5, J6, J7, Justice and OD 6
  to OD 10, as Etterna shows it. Accuracy can go below 0%, as in Etterna, when nearly everything is
  missed.
- **Volume and pause like the other games**: Alt + mouse wheel changes the volume anywhere (osu! /
  Quaver), step by step while the wheel turns; right click on an empty spot of song select pauses or
  resumes the song preview (Etterna).
- **Skip long intros**: when the first note is a while away, "Press Space to skip" shows and Space jumps
  to 3 seconds before it, as osu! and Quaver do (osu!'s rule with the osu! look, Quaver's with the
  Quaver look). Space only skips while that shows, so a 7K key bound to Space plays normally after.
  With pausing off, intros of 8 seconds or more can be skipped (the play then runs on Etterna's
  practice screen, the only one that can move through the song); with pausing on, any intro.
- **Practice mode** (the PR mod in the osu! look, PRACTICE in Quaver's Modifiers; or Tab from the map
  preview): the song plays on Etterna's practice screen, nothing is scored, and a bar along the
  bottom shows the chart's density through the song: click it to jump, right click (or Ctrl + click)
  to set where a loop starts and ends, Backspace to go back there, Esc to pause.
- **Watch replays**: "Watch replay" on the results (osu!'s ranking screen and Quaver's), or right click
  one of your scores on song select. Your mods, noteskin and rate come back afterwards.
- **Pausing, if you want it** ("Pausing" in the options of every look, or Ctrl+P on the main menu, song
  select and results): off, Esc leaves a song as in Etterna. On, Esc pauses it as in osu!, with
  Continue, Retry and Quit (the osu! skin's pause art when it has some) and a 3-2-1 count before the
  song goes on. The results then say "Pauses: N" in green, with a green line on the hit-offset plot
  wherever you paused, as Quaver does (in all five looks). A paused play's score is saved, but marked
  invalid, like Etterna's own "invalidate score": it doesn't count for your rating and EtternaOnline
  gets it as invalid. The score lists show it with "invalid". Notes before your first key press
  aren't judged in a pausable play (it runs on Etterna's practice screen, the only one that can pause).
  After the 3-2-1 the notes go on from where they stopped, without jumping. The mouse pointer shows
  over the pause menu.
  Ctrl+P replaces Etterna's "new playlist" shortcut on song select (the playlist button still works).
- **Frosted glass in the osu! look** (the Quaver look keeps Quaver's own colours): on the main menu,
  song select and results, panels, bars, lists, dialogs and the options show the background behind
  them blurred through a grey tint, like frosted glass, layered by what should stand out: the
  background strip and bars lightest, panels darker, and what opens on top (options, lists,
  dropdowns, dialogs) darkest, so nothing behind it gets in the way. The blur needs Etterna's OpenGL
  renderer (Options > VIDEO > Renderer > OpenGL, from the next start): with Direct3D, Etterna can't
  draw into a picture without crashing the next time it sets the screen up, so the same parts are a
  plain see-through grey there. Elsewhere (gameplay boxes, the map preview, the practice bar) the
  grey is plain see-through. Cards on a panel (the pattern ratings, the
  local ranking, buttons) are a lighter grey, and the song wheel panels get a dark see-through layer
  under the skin's art so their text reads over bright backgrounds.
- **Song select details**: the pattern ratings (MSD) are cards with a bar for each, the local ranking
  shows each score on grey with its grade colour coming in from the left, a failed play shows as a
  grey F (not a D), and the wheel marks played maps with a small grade badge (none for a fail).
- **Skin numbers without stray lines**: a few skins pad every score digit with empty space and cancel
  it with a huge ScoreOverlap (or make the % a long strip); VSRG Hub draws only the part of each
  character that shows, so score and accuracy sit together without faint broken lines across the HUD.
- **Play time per key mode**: the player card shows your play time in the mode you're in (4K or 7K),
  and the profile panel (click the card; PROFILE in the Quaver look) lists it for 4K, 7K and in total.
  It is Etterna's play time (the length of every saved play, the part you survived of a failed one),
  split by each score's chart.
- **Pick your cursor**: Options > Cursor opens a list of pointers with a preview beside it: the look's
  own (the interface skin's cursor in the osu! look, Quaver's pointer in the Quaver look), Etterna's,
  Quaver's, or the cursor of any of your osu! skins. Each is drawn the way its game draws it: an osu!
  cursor at osu!'s size (@2x art at half size, so a skin's cursor is as big as in osu!), with its
  cursormiddle and trail, turning and growing on click as the skin.ini says; Quaver's as a small square
  with its tip on the mouse; Etterna's as its small diamond. Cursor size scales any of them (0.5x to
  2x). The picked cursor is used in all five looks (with "the look's own", Til' Death and Rebirth keep
  Etterna's pointer), in place of the Windows arrow. It hides while you play.
- **Group by pattern**: Group by > Pattern lists Stream, Jumpstream, Handstream, Stamina, JackSpeed,
  Chordjack and Technical. A chart is in every pattern it is rated within 10% of its best one, so a long
  chordjack file can be both Stamina and Chordjack.
- **Map preview** (Quaver's View Map; in the osu! look pick "Map Preview" in the "Local Ranking" box):
  the chart scrolls with the whole song inside its box, the graph beside it shows how hard each part
  is (coloured on the MSD scale) with a line following the song; click anywhere on the graph to jump
  there (the song starts at the bottom), and
  press Tab to play the chart from that point (Etterna's practice mode). While a long note goes by its
  head stays on the receptor, as in osu! and Quaver (VSRG Hub's noteskins, .sm / .ssc charts).
  Changing the noteskin shows at once in the open preview. Clicking one of your scores opens its
  results. The noteskin lists in the options show the noteskin under the cursor playing the selected
  song beside the list; Etterna's Player Options show every column of the noteskin in a small
  playfield left of the options, sized to fit.
- **Mods in the map preview**: with Mirror, Full LN or Inverse on, the map preview shows the chart with
  them (the other mods don't change it).
- **Full LN and Inverse**: Quaver's mods (osu!lazer's "Invert"): every note becomes a long note held
  until just before the next one in its column (Full LN), or the gaps between long notes become the
  long notes (Inverse), worked out the way Quaver does it. Etterna can't change notes while you play,
  so VSRG Hub writes the converted chart once to `Songs/VSRG Hub Mods` and plays that: it has its own
  MSD and its own scores. Back on song select you're on the original chart again.
- **Results like Til' Death**: both looks' results show the MA and PA ratios (marvelous : perfect,
  perfect : great), the clear type (MFC, PFC, SDG, FC, SDCB...), max combo, holds and mines, the judge
  and the score's ratings, and every hit across the whole chart (early below, late above, misses as
  faint red lines, like Etterna's, so a run of misses doesn't hide the rest) with the judge windows,
  mean, standard deviation, largest hit and combo breaks per hand. In 7K the middle key belongs to
  the hand whose thumb plays it: the right one unless Options > "7K thumb on the middle key" says
  left (hands 3 + 4 or 4 + 3). Click a column (or press 1-7, H for hands, 0 for all) to see
  only that finger's hits; switch the judge with < > to see your Wife% rescored from J4 to Justice;
  hover the plot for the time and your judgments up to there.
- **One song, its difficulties inside**: the difficulties of an osu! or Quaver map set are one song
  with its charts to pick from, even when their timing lines differ a little (they only split when
  their tempo really differs). Searching shows how many songs of each pack match.
- **Dan Overlay**: if you use Dan Overlay with Til' Death, it keeps working in the osu! and Quaver looks
  (VSRG Hub loads the hooks it installed).
- **Til' Death and Rebirth: Customize Gameplay** gets a panel in the theme's own style. In Til' Death it
  sets the notefield (position, hit position, width, height, column spacing) with - / + buttons and
  lists every part it lets you move: click Move / Size / Spacing / Turn on a part, then drag it or use
  the arrow keys (Backspace resets it, right click lets go), instead of Til' Death's letter keys. In
  both themes it adds the noteskin rows of the osu! and Quaver looks (note spacing, note size, receptor
  offset / size / width / height, stage hint offset / height, LN tail height / offset), stored with the
  same values, per noteskin; Rebirth keeps its own menu for its parts and the notefield. Both also get
  a lane cover, kept per key mode: off, sudden (over the far end of the lanes) or hidden (over the
  receptors), with its height, opacity and colour (12 colours); while it is on it replaces the theme's
  own lane cover. In Rebirth the noteskin rows and the lane cover are two tabs. The panel can be
  dragged by its title and folded with a click on it.
- **Til' Death**: its chart preview is drawn smaller.
- **A combo the skin puts off the screen**: some osu! skins hide the combo by setting ComboPosition
  below the screen (e.g. 1111). VSRG Hub shows it at osu!'s usual place instead; switch it off or move it
  in Customize gameplay (HUD) if you'd rather not have it.
- **Rate edits and packs stay findable**: a map set holding one song at several rates (each with its own
  audio, e.g. "0.9x", "1.1x") becomes one entry per rate titled "<song> [<difficulty>]", so searching for
  the song finds all of them in every look; packs whose difficulties are named "Artist - Title" keep those
  names as the songs' titles.
- **Every difficulty of a song, in the osu! and Quaver looks**: once the list stops on a song with more
  than one chart, it opens up as in osu!lazer and Quaver and its charts show under it, easiest first: name,
  keys, length, notes, the main pattern type, the MSD at your rate and your best on it (grade and
  accuracy). Click one to pick it, click the picked one to play it. The arrow keys go through them (osu!:
  up / down, Quaver: left / right); past the last one they go on to the next song (on its first chart),
  past the first to the song before (on its last). Til' Death and Rebirth keep their own difficulty list.
- **Profile page, in every look**: a full page in the look's own style, like osu!'s user page with
  Etterna's numbers. Open it from your player card (osu!), PROFILE (Quaver), your profile corner on song
  select (Til' Death bottom left, Rebirth top left) or Profile in the Ctrl+O menu. The header shows your
  avatar, name, play time, arrows hit, your EtternaOnline rating and rank when logged in, and your 4K
  and 7K ratings (click the other one, Space or M to switch). Tabs (click, Tab or 1-4):
  - **Overview**: your rating in each skillset (Overall, Stream, Jumpstream, Handstream, Stamina,
    JackSpeed, Chordjack, Technical) as bars, how many charts you have at each grade, plays, charts
    played, average accuracy, best play, 4K / 7K / total play time, sessions and your last plays.
  - **Top plays**: each chart's best personal best, ranked by SSR; the chips beside the tabs (or A / S)
    rank them by one skillset instead.
  - **Recent plays** and **Most played**: every play, newest first, and the charts you've played most.
  Each row shows the song's banner, title, artist, difficulty, the chart's MSD at the rate played, rate,
  accuracy, grade, SSR and when. Scroll with the wheel or the arrows, left / right turn pages, Esc,
  right click or a click outside closes it. 4K ratings are Etterna's own; 7K uses Etterna's formula on
  your 7K personal bests (Etterna rates only 4K).
- **Lane flash on misses** (off unless you turn it on): Etterna's combo break highlight, a column lit in
  the judgment's colour on a Bad or a Miss, in every look. Switch it in the options (osu! and Quaver
  looks) or the Ctrl+O menu (Til' Death and Rebirth); it decides Etterna's own "CB Highlight".
- **Lane cover** (osu! and Quaver looks, as in Til' Death and Rebirth): off, sudden (over the far end
  of the lanes) or hidden (over the receptors), with its height, opacity and colour (12 colours). A
  skin with a mania-stage-bottom adds a fourth choice, "Skin": that art drawn as osu! draws it, over
  the notes at the bottom of the stage (the top when scrolling up), moved and sized in Customize
  gameplay. Kept per noteskin and key mode. Stage art (sides, bottom) follows the skin.ini's 7K
  section in 7K.
- **Customize gameplay**: Options > Customize gameplay (or Etterna's own Customize Gameplay player
  option, which then opens the editor for the next song you start and turns itself off) plays the
  selected chart on autoplay with an editor over it, separately for 4K and 7K. Its panel is drawn
  in the look's own style (osu!'s settings in the osu! look, Quaver's options dialog in the Quaver
  look) with five tabs: Notefield, Notes, Receptors, Lane cover and HUD. Every value has a slider
  (drag it or click on it), - / + buttons and the mouse wheel; the HUD tab lists every part with a
  switch and the picked part's size. Drag the panel's header to move it out of a wide notefield's
  way; H hides it. Drag
  any part (judgment, combo, score, accuracy, health bar, mods, hit error bar, song time) to move it and
  use the mouse wheel to resize it; drag the notefield sideways to move it and up or down to set the hit
  position. The panel also sets notefield size, column spacing (the gap between columns; notes keep their size), note spacing (how much further apart the notes are than the receptors, for skins whose notes and receptors don't line up; +0 keeps them together), note size (notes, hold heads, bodies and ends bigger or smaller than their column), receptor offset, size, width and height
  (stretch squashed receptors; VSRG Hub's noteskins), the stage hint's offset and height (the hit line is one picture across the whole stage, also for skins without receptors; osu!'s judgement line moves with it), the lane cover (mode, height, opacity, colour), and the
  picked part's size, width and height (Shift + wheel: wider / narrower, Ctrl + wheel: taller /
  flatter), the long note tail's height and offset (VSRG Hub's noteskins; the tail always stays at
  the end of the body, never under the head), the error bar's background opacity (osu! look); it switches parts on and off (hidden parts are hidden) and Etterna's extra parts: error
  bar, progress bar, judgment counter, mean, NPS and pace. Click a part to pick it (right click lets
  go), then drag it or use the wheel; everything is saved as you go (`Save/VSRGHub/layout.ini`), the
  notefield, receptors and lane cover for each noteskin on its own; R resets the picked part. Space
  skips an intro of 8 seconds or more there too, to get to the notes sooner.
- **More in Customize gameplay (every look)**: a Lighting tab (hit lighting / LightingN, hold
  lighting / LightingL and column lighting: each on or off, moved, sized, and its width and height),
  receptors over or under the notes (or as the skin has them), the lane cover's border (none, line,
  fade or glow, its height and colour), and the FPS counter as a HUD part (when Options > Show FPS is
  on): moved, sized, switched off, and its lines (FPS, average FPS, vertices per frame, renderer)
  each shown or hidden; Etterna's own counter steps aside. In Til' Death and Rebirth the panel has
  the same pages (Noteskin, Lighting, Lane cover, HUD).
- **Combo skin**: the combo can use any skin's digits (any osu! skin with combo digits, or a Quaver
  skin's), picked in the options with a preview of them, in the osu! and Quaver looks (Til' Death and
  Rebirth keep their own combo).
- **Quaver's judgement windows**: Peaceful to Impossible, and your own (CREATE, name them by typing,
  set each window with its slider) in Quaver's dialog (Quaver look: Options > Gameplay > Judgement
  windows; the osu! look and the Til' Death / Rebirth menu pick them from a list). Etterna judges on
  those windows (Marvelous to Okay, up to Etterna's 180 ms) and keeps Wife% at J4; the accuracy shown
  while playing and on the results is Quaver's. Combo breaks and long note misses stay as Etterna has
  them.
- **Results**: the big accuracy is on the timing you played with (the judge, osu!'s OD or Quaver's
  windows), J4 small beside it and the other judges in its tooltip; a failed play shows the accuracy
  of what was played. The big grade goes by that accuracy, osu!'s letters in the osu! look (SS 100%,
  S 95, A 90, B 80, C 70) and Quaver's in the Quaver look (X 100%, SS 99, S 95...), so 97% on OD 8 is
  an S; Etterna's grade (AAAA, AA...) is written small by the J4 accuracy. Song select's scoreboard
  shows each score the same way (its grade and accuracy on the timing it was played on, then
  Etterna's grade).
- **Online profile and EtternaOnline**: the profile page has Local / Online. Online shows your
  EtternaOnline profile (when you're logged in): ratings, world and country rank, and top,
  recent and most played from all your online scores. Rankings shows the world's and your country's
  players; click one to see their profile, or type a name and press Enter. VSRG Hub fetches it from
  EtternaOnline while the game runs (it has to be started from VSRG Hub).
- **Logging in to EtternaOnline, in every look**: Log in / Log out on the profile page (also in the
  options' EtternaOnline row, VSRG Hub's Ctrl+O menu in Til' Death and Rebirth, and Rebirth's login
  corner on song select). Type your name or e-mail and password (Ctrl+V pastes); Etterna logs in and
  VSRG Hub remembers the session (Save/VSRGHub/online.ini, as Til' Death keeps it), so the next start
  logs in by itself, whichever look it opens in. Log out forgets it.
- **Song select**: search runs once you stop typing, and the results slide in (osu! and Quaver
  looks); a song's difficulties are listed under it without moving when you pick one; the list no
  longer wraps round (with few songs, the same ones showed again above and below).
- **The launcher**: opening `vsrghub.exe` yourself (or the "VSRG Hub" shortcut it puts on the
  desktop the first time) shows a window with Play, the look to start in (osu!, osu!lazer, Quaver,
  Til' Death, Rebirth) and updates (see Updating). Started by Melty, or with `--play` or a game folder flag, the
  game starts straight away as before. The window uses Windows' WebView2 (built into Windows 10 and
  11; WebView2Loader.dll is next to vsrghub.exe); without it the game simply starts.
- **Online rankings** (osu! and Quaver looks): the ranking box on song select switches between your
  local scores and the chart's EtternaOnline leaderboard (osu!: Local Ranking > Global Ranking > Map
  Preview, right click goes back; Quaver: RANKING: Local / Global). Logged out, it offers the log-in
  box. Clicking an online score fetches its replay and shows it; right click watches it.
- **Song select background**: Options > Background dim (how dark) and Background blur (off, soft,
  strong), for the osu! and Quaver looks, each kept separately. With OpenGL the blur is drawn small and
  stretched back; with Direct3D it is a ring of soft copies.
- **Sharper text**: the osu! look's fonts (Open Sans and Roboto, as Etterna's Common Normal and Common
  Bold) are redrawn at twice the resolution, with copies at four times for big text (the profile
  rating, scores); the Quaver look's Lato gets the big copies too, and Til' Death and Rebirth's profile
  page uses one for its big numbers. Small text uses its own small copies, so it isn't shrunk blurry.
- **Smooth shapes**: the osu! and osu!lazer looks draw their circles, rounded boxes, triangles and lines
  as shapes with a one-pixel soft edge (Etterna has no antialiasing), so the logo, the visualizer,
  buttons and panels stay sharp without jagged edges at any screen size.
- **An icon**: vsrghub.exe, the desktop shortcut, the launcher and the game's window.
- **Quaver skins' stage borders** (stage-left-border / stage-right-border) are drawn beside the columns.
- **7K stages as the skin draws them**: bar-style osu! skins (no receptors, a stage hint line) get their
  hint line at the hit position; other skins get their 7K keys.
- **Mixed by difficulty**: Etterna's sort menu can drop the groups and sort everything, from all three
  games, by difficulty.
- **4K and 7K**: 4K charts play in Etterna's dance mode; Quaver and osu! 7K maps and Qwilight 7-key
  charts play in Etterna's kb7 mode, with Etterna's MSD shown for them too. Qwilight charts with a turntable lane play in Etterna's
  8-lane beat mode.
- **Solo**. Scores save to your Etterna profile like any other song.

Nothing is copied out of Quaver or Qwilight. VSRG Hub writes a small library folder in Etterna's
save folder (`Save/VSRGHub/Library`, next to your settings, so a new version of the VSRGHub folder
finds it and nothing is converted again) holding generated Etterna chart files (.sm) for Quaver maps and folder
junctions that point at the original song folders, then starts Etterna with
`ETTERNA_ADDITIONAL_SONG_DIRS` pointing at it. Skins and the theme come from `VSRG Hub/Root`, which
Etterna mounts over its own folder (`ETTERNA_ADDITIONAL_ROOT_DIRS`); the theme is chosen there through a
`Data/Static.ini` that Etterna never saves to your Preferences.ini. Etterna's own files and settings are
not changed (VSRG Hub only adds `Save/VSRGHub/settings.ini`, `layout.ini` and `keys.ini` with your picks, and
`Songs/VSRG Hub Mods` once you play with Full LN or Inverse; note, restart and rate keys you change in
Keybinds go into Etterna's own key map, as its key config would put them),
and starting Etterna without VSRG Hub gives you your usual setup.
Delete the `VSRGHub` folder and `Save/VSRGHub` to remove it completely.

## Updating

Your songs, settings and layouts live in Etterna's `Save/VSRGHub`, not in the VSRGHub folder, so an
update never converts your library again. To update, either:

- drop the new `VSRGHub-<version>.zip` on `vsrghub.exe`, or
- leave the zip in your Downloads (or Desktop, or Etterna's folder) and start the game: VSRG Hub asks
  whether to install it.

It replaces the program and the themes, removes files the old version had and the new one doesn't,
and starts the new version.

The launcher can also update from the internet: when `update-url.txt` (next to vsrghub.exe) holds the
address of VSRG Hub's update file, it checks it each time it opens and shows "VSRG Hub <version> is
out" with what's new; Update now downloads the zip, checks it against the SHA-256 the update file
gives, installs it the same way and reopens the launcher. Updating from a version older than 1.8.0-beta.21 (which has no updater
yet): extract the new VSRGHub folder over the old one once.

## What is skipped
- osu!mania maps with key counts other than 4 and 7, and maps whose tempo gimmicks go beyond what Etterna
  can hold.
- Quaver 7K maps with a scratch lane (7K+1) and maps whose audio file is missing from the set.
- Qwilight songs made only of keysounds with no full music track: Etterna needs a music file for every song.
- Qwilight .bmson charts (Etterna reads .bms, .bme, .bml and .pms).
- Quaver scroll-velocity (SV) changes: charts play at Etterna's constant scroll. BPM changes are kept.

`VSRGHub/vsrghub.log` lists what was found and skipped on each launch.

## Notes
- The first launch reads every Quaver and osu! map, and Etterna then reads each new song once. With a big
  osu! library this first start can take a long time; later launches reuse that work and only re-read sets
  that changed.
- The first time you play in kb7 or beat mode, pick a noteskin for that mode in VSRG Hub's options.
- Skin images Etterna can't open (for example one saved in a format other than PNG, or one taller than
  8192 pixels) are left out of that noteskin; the log says which. Hold bodies are the exception: VSRG Hub
  converts the skin's own body into a PNG Etterna can load (once; it's redone only when the skin's file
  changes) and stretches it over each long note, so long notes keep their look.
- VSRG Hub only switches Etterna to its themes while VSRG Hub is running; afterwards it puts your own
  theme setting back, so starting Etterna on its own looks as it always did.
- A black screen after Alt+Tab (the game keeps running but draws nothing) is Etterna's Direct3D
  renderer losing its screen. Alt+Enter twice (windowed and back) can bring it back; Options > VIDEO >
  Renderer > OpenGL (from the next start) avoids it, and also gives the osu! look its frosted glass.

## Credits
- VSRG Hub, built with Claude.
- Etterna (etternagame), Quaver (Swan), Qwilight (Taehui) and osu! (ppy) belong to their makers; every chart, song,
  skin and image comes from your own installs, except Quaver's mouse pointer (the Quaver cursor), which
  is Quaver's main-cursor.png from Quaver.Resources by the Quaver team, used under CC BY-NC 4.0
  (scaled down; VSRG Hub is free and not sold). The VSRG Hub osu! theme builds on Til Death, Etterna's
  default theme, which it loads from your Etterna install.
- The Quaver look's text uses bitmap fonts drawn from Lato by Łukasz Dziedzic (SIL Open Font License 1.1),
  renamed "twsans" as the license asks for changed versions; Japanese, Chinese and Korean text falls back
  to Til Death's font.
- The osu!lazer look's text uses bitmap fonts drawn from Nunito by Vernon Adams, Cyreal and Jacques Le
  Bailly (SIL Open Font License 1.1), renamed "_lz" / "_lzx" for the same reason. osu!lazer's look is
  ppy's; VSRG Hub only draws something like it.
- The icons on the osu! and osu!lazer looks' buttons are Font Awesome Free icons by Fonticons, Inc.
  (CC BY 4.0), drawn as white pictures.
- Uses gopkg.in/yaml.v3 (MIT and Apache-2.0), golang.org/x/sys and golang.org/x/image (BSD-3-Clause).
