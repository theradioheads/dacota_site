#!/bin/bash

# GitHub Pages Publisher & Optimizer Script for Jri Radio
# This script processes .jlres3 files, extracts metadata, and sets up GitHub Pages

set -e  # Exit on any error

echo "🚀 Starting Jri Radio GitHub Pages Publisher & Optimizer"

# Configuration
SITE_DIR="site"
FILECOUNT_FILE="$SITE_DIR/filecount.txt"
FILEDATA_FILE="$SITE_DIR/filedata.txt"
DATE_FILE="$SITE_DIR/date.txt"
RADIO_FILE="$SITE_DIR/index.html"      # Radio interface (main page)
PLAYER_FILE="$SITE_DIR/player.html"    # Player interface

# Create site directory if it doesn't exist
mkdir -p "$SITE_DIR"

echo "📁 Created/verified site directory"

# Function to check if required tools are installed
check_dependencies() {
    echo "🔍 Checking dependencies..."
    
    if ! command -v ffprobe &> /dev/null; then
        echo "❌ ffprobe not found. Installing ffmpeg..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y ffmpeg
        elif command -v yum &> /dev/null; then
            sudo yum install -y ffmpeg
        else
            echo "❌ Cannot install ffmpeg automatically. Please install it manually."
            exit 1
        fi
    fi
    
    echo "✅ Dependencies checked"
}

# Function to count .jlres3 files
count_files() {
    echo "📊 Counting .jlres3 files..."
    
    local count=$(find . -name "*.jlres3" -type f | wc -l)
    echo "$count" > "$FILECOUNT_FILE"
    
    echo "✅ Found $count .jlres3 files, saved to $FILECOUNT_FILE"
}

# Function to extract base64 image from audio file
extract_image_base64() {
    local audio_file="$1"
    local temp_image="/tmp/cover_$$.jpg"
    
    # Try to extract cover art using ffmpeg
    if ffmpeg -i "$audio_file" -an -vcodec copy "$temp_image" 2>/dev/null; then
        # Convert to base64
        local base64_data=$(base64 -w 0 "$temp_image" 2>/dev/null || base64 "$temp_image" 2>/dev/null)
        rm -f "$temp_image"
        echo "data:image/jpeg;base64,$base64_data"
    else
        echo ""  # No image found
    fi
}

# Function to extract metadata from audio files
extract_metadata() {
    echo "🎵 Extracting metadata from .jlres3 files..."
    
    # Clear the filedata file
    > "$FILEDATA_FILE"
    
    local processed=0
    local total=$(cat "$FILECOUNT_FILE")
    
    # Find all .jlres3 files and process them
    while IFS= read -r -d '' jlres3_file; do
        processed=$((processed + 1))
        echo "Processing ($processed/$total): $(basename "$jlres3_file")"
        
        # Create temporary MP3 file by copying and renaming
        local temp_mp3="${jlres3_file}.mp3"
        cp "$jlres3_file" "$temp_mp3"
        
        # Extract metadata using ffprobe
        local title=""
        local artist=""
        local img_data=""
        
        # Get title
        title=$(ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$temp_mp3" 2>/dev/null | head -1 | tr -d '\n\r' | sed 's/=/_EQUAL_/g')
        if [ -z "$title" ]; then
            # Fallback to filename without extension
            title=$(basename "$jlres3_file" .jlres3)
        fi
        
        # Get artist
        artist=$(ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$temp_mp3" 2>/dev/null | head -1 | tr -d '\n\r' | sed 's/=/_EQUAL_/g')
        if [ -z "$artist" ]; then
            artist="Unknown Artist"
        fi
        
        # Extract cover image as base64
        img_data=$(extract_image_base64 "$temp_mp3")
        if [ -z "$img_data" ]; then
            img_data="none"
        fi
        
        # Clean up temp file
        rm -f "$temp_mp3"
        
        # Save to filedata.txt in format: (filename=title=artist=imgdata)
        echo "($(basename "$jlres3_file")=$title=$artist=$img_data)" >> "$FILEDATA_FILE"
        
    done < <(find . -name "*.jlres3" -type f -print0)
    
    echo "✅ Metadata extraction complete, saved to $FILEDATA_FILE"
}

# Function to get commit date
get_commit_date() {
    echo "📅 Getting commit date..."
    
    # Get the current commit date in ISO format
    local commit_date=$(git log -1 --format="%cI" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$commit_date" > "$DATE_FILE"
    
    echo "✅ Commit date saved to $DATE_FILE: $commit_date"
}

# Function to create optimized radio.html (now index.html) for GitHub Pages
create_radio_html() {
    echo "🌐 Creating/updating index.html (Radio) for GitHub Pages..."
    
    cat > "$RADIO_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dacota Radio</title>
    <style>
:root {
    --bg-color: linear-gradient(45deg, #ffeb3b, #2d3436);
    --container-bg: #fff;
    --text-color: #ffeb3b;
    --secondary-text: #ffeb3b;
    --light-text: #999;
    --play-button-bg: #ffeb3b;
    --play-button-hover: #ffd54f;
    --next-button-bg: #ffeb3b;
    --next-button-hover: #ffd54f;
    --progress-bg: #ddd;
    --progress-fill: #ffeb3b;
    --shadow-color: rgba(0, 0, 0, 0.1);
    --error-bg: #ffebee;
    --error-border: #f44336;
    --error-text: #c62828;
    --artist-controller-bg: #f8f9fa;
    --artist-controller-border: #e9ecef;
    --button-text: #000;
}

body.dark-mode {
    --bg-color: #2d3436;
    --container-bg: #1e1e1e;
    --text-color: #e0e0e0;
    --secondary-text: #b0b0b0;
    --light-text: #909090;
    --play-button-bg: #2d3436;
    --play-button-hover: #b2bec3;
    --next-button-bg: #2d3436;
    --next-button-hover: #404040;
    --progress-bg: #424242;
    --progress-fill: #ffeb3b;
    --shadow-color: rgba(0, 0, 0, 0.3);
    --error-bg: #2d1b1b;
    --error-border: #d32f2f;
    --error-text: #ef5350;
    --artist-controller-bg: #2a2a2a;
    --artist-controller-border: #404040;
    --button-text: #ffeb3b;
}

body {
    font-family: Arial, sans-serif;
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
    background: var(--bg-color);
    color: var(--text-color);
    transition: background-color 0.3s, color 0.3s;
}

.player-container {
    background-color: var(--container-bg);
    border-radius: 8px;
    box-shadow: 0 2px 10px var(--shadow-color);
    padding: 20px;
    margin-bottom: 20px;
    transition: background-color 0.3s, box-shadow 0.3s;
}

.track-info {
    display: flex;
    margin-bottom: 20px;
}

.cover-art {
    width: 200px;
    height: 200px;
    background-color: #333;
    margin-right: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    border-radius: 8px;
}

.cover-art img {
    max-width: 100%;
    max-height: 100%;
    object-fit: cover;
}

.track-details {
    flex: 1;
}

.track-title {
    font-size: 24px;
    font-weight: bold;
    margin-bottom: 10px;
}

.track-artist {
    font-size: 18px;
    color: var(--secondary-text);
    margin-bottom: 15px;
}

.controls {
    display: flex;
    align-items: center;
    margin-bottom: 20px;
    gap: 10px;
}

.play-button, .next-button, .artist-controller-toggle {
    color: var(--button-text);
    border: none;
    padding: 10px 20px;
    text-align: center;
    font-size: 16px;
    cursor: pointer;
    border-radius: 4px;
    transition: background-color 0.2s;
}

.play-button {
    background-color: var(--play-button-bg);
    min-width: 100px;
}

.next-button, .artist-controller-toggle {
    background-color: var(--next-button-bg);
}

.play-button:hover {
    background-color: var(--play-button-hover);
}

.next-button:hover, .artist-controller-toggle:hover {
    background-color: var(--next-button-hover);
}

.progress-container {
    height: 8px;
    background-color: var(--progress-bg);
    border-radius: 4px;
    margin: 10px 0;
    width: 100%;
    cursor: pointer;
}

.progress-bar {
    height: 100%;
    background-color: var(--progress-fill);
    border-radius: 4px;
    width: 0;
    transition: width 0.1s linear;
}

.time-display {
    display: flex;
    justify-content: space-between;
    font-size: 14px;
    color: var(--secondary-text);
    margin-top: 5px;
}

.loading-indicator {
    text-align: center;
    padding: 20px;
    font-style: italic;
    color: var(--secondary-text);
}

.theme-toggle {
    background: none;
    border: none;
    color: var(--secondary-text);
    cursor: pointer;
    font-size: 14px;
    padding: 5px 10px;
    border-radius: 4px;
    margin-left: 10px;
}

.header {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.header-controls {
    display: flex;
    align-items: center;
}

.volume-control {
    display: flex;
    align-items: center;
    margin-left: 15px;
}

.volume-control input[type="range"] {
    width: 100px;
    height: 6px;
    -webkit-appearance: none;
    background: var(--progress-bg);
    border-radius: 3px;
    outline: none;
    margin: 0 10px;
}

.error-message {
    background-color: var(--error-bg);
    border: 1px solid var(--error-border);
    color: var(--error-text);
    padding: 15px;
    border-radius: 8px;
    margin: 20px 0;
}

.player-link {
    display: block;
    text-align: center;
    margin-top: 20px;
    color: var(--primary-color);
    text-decoration: none;
    font-weight: bold;
}

.player-link:hover {
    text-decoration: underline;
}

.artist-controller {
    background-color: var(--artist-controller-bg);
    border: 1px solid var(--artist-controller-border);
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 20px;
    display: none;
}

.artist-controller.show {
    display: block;
}

.artist-controller h3 {
    margin-top: 0;
    margin-bottom: 15px;
    font-size: 18px;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.artist-controller-actions {
    display: flex;
    gap: 10px;
    margin-bottom: 15px;
}

.select-all-btn, .select-none-btn {
    background: var(--secondary-text);
    color: white;
    border: none;
    padding: 5px 10px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    transition: background-color 0.2s;
}

.select-all-btn:hover, .select-none-btn:hover {
    background: var(--text-color);
}

.artist-list {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 10px;
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid var(--artist-controller-border);
    border-radius: 4px;
    padding: 10px;
}

.artist-item {
    display: flex;
    align-items: center;
    padding: 5px;
    border-radius: 4px;
    transition: background-color 0.2s;
}

.artist-item:hover {
    background-color: rgba(0, 0, 0, 0.05);
}

body.dark-mode .artist-item:hover {
    background-color: rgba(255, 255, 255, 0.05);
}

.artist-item input[type="checkbox"] {
    margin-right: 8px;
}

.artist-item label {
    cursor: pointer;
    flex: 1;
    font-size: 14px;
}

.artist-track-count {
    color: var(--secondary-text);
    font-size: 12px;
    margin-left: 5px;
}

#audio-player {
    display: none;
}

@media (max-width: 600px) {
    .track-info {
        flex-direction: column;
    }

    .cover-art {
        margin-right: 0;
        margin-bottom: 15px;
        align-self: center;
    }

    .artist-list {
        grid-template-columns: 1fr;
    }
}

    </style>
</head>
<body>
    <div class="header">
        <h1>Dacota Radio</h1>
        <div class="header-controls">
            <button id="theme-toggle" class="theme-toggle">Dark Mode</button>
        </div>
    </div>
    
    <div class="artist-controller" id="artist-controller">
        <h3>
            Artist Controller
            <span class="artist-track-count" id="enabled-count">All artists enabled</span>
        </h3>
        <div class="artist-controller-actions">
            <button class="select-all-btn" id="select-all-btn">Select All</button>
            <button class="select-none-btn" id="select-none-btn">Select None</button>
        </div>
        <div class="artist-list" id="artist-list">
            <!-- Artists will be populated here -->
        </div>
    </div>
    
    <div class="player-container">
        <div id="loading" class="loading-indicator">Loading music library...</div>
        
        <div id="error-display" class="error-message" style="display: none;">
            Unable to load music files. This GitHub Pages version requires the files to be properly configured.
        </div>
        
        <div id="player-ui" style="display: none;">
            <div class="track-info">
                <div class="cover-art">
                    <img id="cover-image" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=" alt="Album Art">
                </div>
                <div class="track-details">
                    <div class="track-title" id="track-title">Loading...</div>
                    <div class="track-artist" id="track-artist">-</div>
                </div>
            </div>
            
            <audio id="audio-player" controls></audio>
            
            <div class="progress-container" id="progress-container">
                <div class="progress-bar" id="progress-bar"></div>
            </div>
            
            <div class="time-display">
                <span id="current-time">0:00</span>
                <span id="total-time">0:00</span>
            </div>
            
            <div class="controls">
                <button class="play-button" id="play-button">Play</button>
                <button class="next-button" id="next-button">Next Track</button>
                <button class="artist-controller-toggle" id="artist-controller-toggle">Artist Filter</button>
                <div class="volume-control">
                    <input type="range" id="volume-slider" min="0" max="1" step="0.05" value="1">
                </div>
            </div>
            
            <a href="player.html" class="player-link">Open Full Music Player →</a>
        </div>
    </div>

    <script>
        // GitHub Pages optimized version of Dacota Radio with Artist Controller
        class DacotaRadioPlayer {
            constructor() {
                this.audioPlayer = document.getElementById('audio-player');
                this.playButton = document.getElementById('play-button');
                this.nextButton = document.getElementById('next-button');
                this.artistControllerToggle = document.getElementById('artist-controller-toggle');
                this.artistController = document.getElementById('artist-controller');
                this.artistList = document.getElementById('artist-list');
                this.selectAllBtn = document.getElementById('select-all-btn');
                this.selectNoneBtn = document.getElementById('select-none-btn');
                this.enabledCount = document.getElementById('enabled-count');
                this.coverImage = document.getElementById('cover-image');
                this.trackTitle = document.getElementById('track-title');
                this.trackArtist = document.getElementById('track-artist');
                this.progressBar = document.getElementById('progress-bar');
                this.progressContainer = document.getElementById('progress-container');
                this.currentTimeDisplay = document.getElementById('current-time');
                this.totalTimeDisplay = document.getElementById('total-time');
                this.loadingIndicator = document.getElementById('loading');
                this.playerUI = document.getElementById('player-ui');
                this.errorDisplay = document.getElementById('error-display');
                this.volumeSlider = document.getElementById('volume-slider');
                this.themeToggle = document.getElementById('theme-toggle');
                
                this.tracks = [];
                this.enabledTracks = []; // Shuffled list of enabled tracks only
                this.allArtists = new Map(); // Map of artist name -> track count
                this.enabledArtists = new Set();
                this.currentTrackIndex = 0;
                this.isPlaying = false;
                this.hasUserInteracted = false;
                this.artistControllerVisible = false;
                
                this.init();
                
                // Track user interaction for autoplay
                document.addEventListener('click', () => {
                    this.hasUserInteracted = true;
                }, { once: true });
                
                document.addEventListener('keydown', () => {
                    this.hasUserInteracted = true;
                }, { once: true });
            }
            
            async init() {
                this.setupEventListeners();
                await this.loadTrackData();
                this.setupArtistController();
                this.loadTrack(0);
                this.loadSavedSettings();
            }
            
            loadSavedSettings() {
                // Load saved volume
                const savedVolume = localStorage.getItem('dacotaRadioVolume');
                if (savedVolume) {
                    this.volumeSlider.value = savedVolume;
                    this.audioPlayer.volume = savedVolume;
                }
                
                // Load saved theme
                const isDarkMode = localStorage.getItem('dacotaRadioDarkMode') === 'true';
                if (isDarkMode) {
                    document.body.classList.add('dark-mode');
                    this.themeToggle.textContent = 'Light Mode';
                }
                
                // Load saved artist preferences
                const savedArtists = localStorage.getItem('dacotaRadioEnabledArtists');
                if (savedArtists) {
                    this.enabledArtists = new Set(JSON.parse(savedArtists));
                    // Re-shuffle with new artist selection
                    this.shuffleEnabledTracks();
                } else {
                    // Default: enable all artists
                    this.enabledArtists = new Set(this.allArtists.keys());
                }
                
                // Load artist controller visibility
                const controllerVisible = localStorage.getItem('dacotaRadioArtistControllerVisible') === 'true';
                if (controllerVisible) {
                    this.toggleArtistController();
                }
            }
            
            setupEventListeners() {
                this.playButton.addEventListener('click', () => this.togglePlay());
                this.nextButton.addEventListener('click', () => this.nextTrack());
                this.artistControllerToggle.addEventListener('click', () => this.toggleArtistController());
                this.selectAllBtn.addEventListener('click', () => this.selectAllArtists());
                this.selectNoneBtn.addEventListener('click', () => this.selectNoArtists());
                this.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
                this.themeToggle.addEventListener('click', () => this.toggleTheme());
                
                this.audioPlayer.addEventListener('timeupdate', () => this.updateProgress());
                this.audioPlayer.addEventListener('ended', () => this.nextTrack());
                this.audioPlayer.addEventListener('loadedmetadata', () => this.updateTimeDisplay());
                this.audioPlayer.addEventListener('canplay', () => this.handleCanPlay());
                this.audioPlayer.addEventListener('error', (e) => this.handleAudioError(e));
                
                this.progressContainer.addEventListener('click', (e) => this.seek(e));
            }
            
            handleCanPlay() {
                // Auto-start playback if user has interacted and this is the first track
                if (this.hasUserInteracted && this.currentTrackIndex === 0 && !this.isPlaying) {
                    this.togglePlay();
                }
            }
            
            handleAudioError(e) {
                console.error('Audio error:', e);
                console.log('Error details:', this.audioPlayer.error);
                // Try next track on error
                setTimeout(() => this.nextTrack(), 1000);
            }
            
            async loadTrackData() {
                try {
                    // Load file count
                    const countResponse = await fetch('./filecount.txt');
                    if (!countResponse.ok) throw new Error('Could not load file count');
                    const fileCount = parseInt(await countResponse.text());
                    
                    if (fileCount === 0) {
                        this.showError('No music files found.');
                        return;
                    }
                    
                    // Load file data
                    const dataResponse = await fetch('./filedata.txt');
                    if (!dataResponse.ok) throw new Error('Could not load file data');
                    const fileData = await dataResponse.text();
                    
                    // Parse file data
                    this.parseTrackData(fileData);
                    
                    if (this.tracks.length === 0) {
                        this.showError('No valid music files found.');
                        return;
                    }
                    
                    // Extract all artists
                    this.extractArtists();
                    
                    // Initial shuffle and filter
                    this.shuffleEnabledTracks();
                    
                } catch (error) {
                    console.error('Error loading track data:', error);
                    this.showError('Error loading music library.');
                }
            }
            
            parseTrackData(data) {
                // Parse format: (filename=title=artist=imgdata)
                const lines = data.trim().split('\n');
                this.tracks = [];
                
                for (const line of lines) {
                    if (line.startsWith('(') && line.endsWith(')')) {
                        const content = line.slice(1, -1); // Remove parentheses
                        const parts = content.split('=');
                        
                        if (parts.length >= 3) {
                            this.tracks.push({
                                filename: parts[0],
                                title: parts[1].replace(/_EQUAL_/g, '='),
                                artist: parts[2].replace(/_EQUAL_/g, '='),
                                image: parts[3] && parts[3] !== 'none' ? parts[3] : null
                            });
                        }
                    }
                }
            }
            
            extractArtists() {
                this.allArtists.clear();
                
                // Count tracks per artist
                for (const track of this.tracks) {
                    const count = this.allArtists.get(track.artist) || 0;
                    this.allArtists.set(track.artist, count + 1);
                }
                
                // Sort artists alphabetically
                this.allArtists = new Map([...this.allArtists.entries()].sort());
            }
            
            setupArtistController() {
                this.artistList.innerHTML = '';
                
                for (const [artist, count] of this.allArtists) {
                    const artistItem = document.createElement('div');
                    artistItem.className = 'artist-item';
                    
                    const checkbox = document.createElement('input');
                    checkbox.type = 'checkbox';
                    checkbox.id = `artist-${artist.replace(/[^a-zA-Z0-9]/g, '_')}`;
                    checkbox.checked = this.enabledArtists.has(artist);
                    checkbox.addEventListener('change', () => this.toggleArtist(artist, checkbox.checked));
                    
                    const label = document.createElement('label');
                    label.htmlFor = checkbox.id;
                    label.textContent = artist;
                    
                    const trackCount = document.createElement('span');
                    trackCount.className = 'artist-track-count';
                    trackCount.textContent = `(${count})`;
                    
                    artistItem.appendChild(checkbox);
                    artistItem.appendChild(label);
                    artistItem.appendChild(trackCount);
                    this.artistList.appendChild(artistItem);
                }
                
                this.updateEnabledCount();
            }
            
            toggleArtist(artist, enabled) {
                if (enabled) {
                    this.enabledArtists.add(artist);
                } else {
                    this.enabledArtists.delete(artist);
                }
                
                // Ensure at least one artist remains enabled
                if (this.enabledArtists.size === 0) {
                    this.enabledArtists.add(artist);
                    // Re-check the checkbox
                    const checkbox = document.getElementById(`artist-${artist.replace(/[^a-zA-Z0-9]/g, '_')}`);
                    if (checkbox) checkbox.checked = true;
                }
                
                this.saveArtistPreferences();
                this.updateEnabledCount();
                this.shuffleEnabledTracks(); // Re-shuffle when artists change
            }
            
            selectAllArtists() {
                this.enabledArtists = new Set(this.allArtists.keys());
                this.updateArtistCheckboxes();
                this.saveArtistPreferences();
                this.updateEnabledCount();
                this.shuffleEnabledTracks(); // Re-shuffle when artists change
            }
            
            selectNoArtists() {
                // Keep only the first artist enabled to ensure at least one remains
                const firstArtist = this.allArtists.keys().next().value;
                this.enabledArtists = new Set([firstArtist]);
                this.updateArtistCheckboxes();
                this.saveArtistPreferences();
                this.updateEnabledCount();
                this.shuffleEnabledTracks(); // Re-shuffle when artists change
            }
            
            updateArtistCheckboxes() {
                for (const [artist] of this.allArtists) {
                    const checkbox = document.getElementById(`artist-${artist.replace(/[^a-zA-Z0-9]/g, '_')}`);
                    if (checkbox) {
                        checkbox.checked = this.enabledArtists.has(artist);
                    }
                }
            }
            
            updateEnabledCount() {
                const enabledCount = this.enabledArtists.size;
                const totalCount = this.allArtists.size;
                
                if (enabledCount === totalCount) {
                    this.enabledCount.textContent = 'All artists enabled';
                } else {
                    this.enabledCount.textContent = `${enabledCount}/${totalCount} artists enabled`;
                }
            }
            
            saveArtistPreferences() {
                localStorage.setItem('dacotaRadioEnabledArtists', JSON.stringify([...this.enabledArtists]));
            }
            
            toggleArtistController() {
                this.artistControllerVisible = !this.artistControllerVisible;
                
                if (this.artistControllerVisible) {
                    this.artistController.classList.add('show');
                    this.artistControllerToggle.textContent = 'Hide Filter';
                } else {
                    this.artistController.classList.remove('show');
                    this.artistControllerToggle.textContent = 'Artist Filter';
                }
                
                localStorage.setItem('dacotaRadioArtistControllerVisible', this.artistControllerVisible);
            }
            
            shuffleEnabledTracks() {
                // Filter tracks to only include enabled artists
                this.enabledTracks = this.tracks.filter(track => 
                    this.enabledArtists.has(track.artist)
                );
                
                // Shuffle the enabled tracks
                for (let i = this.enabledTracks.length - 1; i > 0; i--) {
                    const j = Math.floor(Math.random() * (i + 1));
                    [this.enabledTracks[i], this.enabledTracks[j]] = [this.enabledTracks[j], this.enabledTracks[i]];
                }
                
                // Reset current track index
                this.currentTrackIndex = 0;
                
                console.log(`Shuffled ${this.enabledTracks.length} enabled tracks`);
            }
            
            shuffleTracks() {
                // Legacy method - now just calls shuffleEnabledTracks
                this.shuffleEnabledTracks();
            }
            
            loadTrack(index) {
                // Ensure we have enabled tracks
                if (this.enabledTracks.length === 0) {
                    // Fallback: enable all artists and reshuffle
                    this.enabledArtists = new Set(this.allArtists.keys());
                    this.updateArtistCheckboxes();
                    this.saveArtistPreferences();
                    this.updateEnabledCount();
                    this.shuffleEnabledTracks();
                }
                
                // If we've reached the end of enabled tracks, reshuffle
                if (index >= this.enabledTracks.length) {
                    this.shuffleEnabledTracks();
                    index = 0;
                }
                
                this.currentTrackIndex = index;
                const track = this.enabledTracks[index];
                
                // Load audio file using GitHub raw URL
                this.loadAudioFile(track);
                
                this.trackTitle.textContent = track.title;
                this.trackArtist.textContent = track.artist;
                
                if (track.image) {
                    this.coverImage.src = track.image;
                } else {
                    this.coverImage.src = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
                }
                
                this.updateDocumentTitle();
                this.showPlayer();
            }
            
            async loadAudioFile(track) {
                try {
                    console.log(`Loading audio file: ${track.filename}`);
                    
                    // Only use GitHub raw URL method
                    const repoUrl = window.location.hostname.includes('github.io') ? 
                        window.location.hostname.replace('.github.io', '') : 'Jri-creator/jri_site';
                    
                    this.audioPlayer.src = `https://raw.githubusercontent.com/theradioheads/dacota_site/refs/heads/main/${track.filename}`;
                    this.audioPlayer.load();
                    
                    console.log(`Audio source set to: ${this.audioPlayer.src}`);
                    
                } catch (error) {
                    console.error('Error loading audio file:', error);
                    this.showError(`Cannot load audio file: ${track.filename}`);
                }
            }
            
            showPlayer() {
                this.loadingIndicator.style.display = 'none';
                this.errorDisplay.style.display = 'none';
                this.playerUI.style.display = 'block';
            }
            
            showError(message) {
                this.loadingIndicator.style.display = 'none';
                this.playerUI.style.display = 'none';
                this.errorDisplay.textContent = message;
                this.errorDisplay.style.display = 'block';
            }
            
            togglePlay() {
                if (this.isPlaying) {
                    this.audioPlayer.pause();
                    this.playButton.textContent = 'Play';
                    this.isPlaying = false;
                } else {
                    const playPromise = this.audioPlayer.play();
                    if (playPromise !== undefined) {
                        playPromise.then(() => {
                            this.playButton.textContent = 'Pause';
                            this.isPlaying = true;
                        }).catch(e => {
                            console.log('Playback failed:', e);
                            if (!this.hasUserInteracted) {
                                this.showError('Please click to start playback (browser autoplay policy)');
                            }
                        });
                    }
                }
                this.updateDocumentTitle();
            }
            
            nextTrack() {
                this.loadTrack(this.currentTrackIndex + 1);
                if (this.isPlaying && this.hasUserInteracted) {
                    // Delay to ensure new track is loaded
                    setTimeout(() => {
                        this.audioPlayer.play().catch(e => console.log('Auto-play failed:', e));
                    }, 100);
                }
            }
            
            setVolume(volume) {
                this.audioPlayer.volume = volume;
                localStorage.setItem('dacotaRadioVolume', volume);
            }
            
            updateProgress() {
                if (this.audioPlayer.duration) {
                    const progress = (this.audioPlayer.currentTime / this.audioPlayer.duration) * 100;
                    this.progressBar.style.width = `${progress}%`;
                    this.currentTimeDisplay.textContent = this.formatTime(this.audioPlayer.currentTime);
                }
            }
            
            updateTimeDisplay() {
                if (this.audioPlayer.duration) {
                    this.totalTimeDisplay.textContent = this.formatTime(this.audioPlayer.duration);
                }
            }
            
            formatTime(seconds) {
                if (isNaN(seconds)) return '0:00';
                seconds = Math.floor(seconds);
                const minutes = Math.floor(seconds / 60);
                seconds = seconds % 60;
                return `${minutes}:${seconds.toString().padStart(2, '0')}`;
            }
            
            seek(e) {
                if (this.audioPlayer.duration) {
                    const rect = this.progressContainer.getBoundingClientRect();
                    const percent = (e.clientX - rect.left) / rect.width;
                    this.audioPlayer.currentTime = percent * this.audioPlayer.duration;
                }
            }
            
            updateDocumentTitle() {
                if (this.enabledTracks.length > 0) {
                    const track = this.enabledTracks[this.currentTrackIndex];
                    const baseTitle = this.isPlaying ? 
                        ` ${track.title} - ${track.artist}` : 
                        ` ${track.title} - ${track.artist}`;
                    document.title = baseTitle;
                } else {
                    document.title = 'Dacota Radio';
                }
            }
            
            toggleTheme() {
                document.body.classList.toggle('dark-mode');
                const isDark = document.body.classList.contains('dark-mode');
                this.themeToggle.textContent = isDark ? 'Light Mode' : 'Dark Mode';
                localStorage.setItem('dacotaRadioDarkMode', isDark);
            }
        }
        
        // Initialize player when DOM is loaded
        document.addEventListener('DOMContentLoaded', () => {
            new DacotaRadioPlayer();
        });
    </script>
</body>
</html>
EOF

    echo "✅ Created optimized index.html (Radio) for GitHub Pages"
}

# Function to create optimized player.html for GitHub Pages
create_player_html() {
    echo "🌐 Creating/updating player.html for GitHub Pages..."
    
    cat > "$PLAYER_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Jri Music Player</title>
    <style>
        :root {
            --bg-color: #f0f2f5;
            --container-bg: #fff;
            --text-color: #333;
            --secondary-text: #777;
            --light-text: #999;
            --primary-color: #2196F3;
            --primary-hover: #0b7dda;
            --play-button-bg: #4CAF50;
            --play-button-hover: #45a049;
            --progress-bg: #ddd;
            --progress-fill: #4CAF50;
            --shadow-color: rgba(0, 0, 0, 0.1);
            --error-bg: #ffebee;
            --error-border: #f44336;
            --error-text: #c62828;
            --library-bg: #f8f9fa;
            --track-hover: #e9ecef;
            --track-active: #e3f2fd;
            --border-color: #e0e0e0;
            --active-control: #4CAF50;
        }
        
        body.dark-mode {
            --bg-color: #121212;
            --container-bg: #1e1e1e;
            --text-color: #e0e0e0;
            --secondary-text: #b0b0b0;
            --light-text: #909090;
            --primary-color: #64b5f6;
            --primary-hover: #90caf9;
            --play-button-bg: #388e3c;
            --play-button-hover: #2e7d32;
            --progress-bg: #424242;
            --progress-fill: #4CAF50;
            --shadow-color: rgba(0, 0, 0, 0.3);
            --error-bg: #2d1b1b;
            --error-border: #d32f2f;
            --error-text: #ef5350;
            --library-bg: #2d2d2d;
            --track-hover: #333;
            --track-active: #0d3a6b;
            --border-color: #424242;
            --active-control: #4CAF50;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Helvetica Neue', Arial, sans-serif;
        }
        
        body {
            background-color: var(--bg-color);
            color: var(--text-color);
            transition: background-color 0.3s ease, color 0.3s ease;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
            padding-bottom: 16px;
            border-bottom: 2px solid var(--border-color);
        }
        
        .header h1 {
            font-size: 32px;
            font-weight: 700;
            color: var(--primary-color);
            letter-spacing: -0.5px;
        }
        
        .theme-toggle {
            background: transparent;
            border: 2px solid var(--primary-color);
            color: var(--primary-color);
            padding: 10px 20px;
            border-radius: 25px;
            cursor: pointer;
            font-weight: 600;
            font-size: 14px;
            transition: all 0.3s ease;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .theme-toggle:hover {
            background-color: var(--primary-color);
            color: white;
            transform: translateY(-1px);
        }
        
        .container {
            display: flex;
            flex-direction: column;
            gap: 24px;
        }
        
        @media (min-width: 900px) {
            .container {
                flex-direction: row;
            }
            
            .library-container {
                flex: 0 0 320px;
            }
            
            .player-container {
                flex: 1;
            }
        }
        
        .panel {
            background-color: var(--container-bg);
            border-radius: 16px;
            box-shadow: 0 8px 24px var(--shadow-color);
            overflow: hidden;
            transition: all 0.3s ease;
            border: 1px solid var(--border-color);
        }
        
        .panel:hover {
            box-shadow: 0 12px 32px var(--shadow-color);
        }
        
        .panel-header {
            padding: 20px 24px;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: linear-gradient(135deg, var(--container-bg) 0%, var(--library-bg) 100%);
        }
        
        .panel-title {
            font-size: 20px;
            font-weight: 600;
            color: var(--text-color);
        }
        
        .search-container {
            position: relative;
        }
        
        .search-container input {
            padding: 10px 16px;
            padding-left: 40px;
            border: 2px solid var(--border-color);
            border-radius: 25px;
            background-color: var(--container-bg);
            color: var(--text-color);
            width: 100%;
            max-width: 260px;
            font-size: 14px;
            transition: all 0.3s ease;
        }
        
        .search-container input:focus {
            outline: none;
            border-color: var(--primary-color);
            box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
        }
        
        .search-icon {
            position: absolute;
            left: 14px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--secondary-text);
            font-size: 16px;
        }
        
        .panel-content {
            padding: 24px;
        }
        
        .library-list {
            max-height: 450px;
            overflow-y: auto;
            scrollbar-width: thin;
            scrollbar-color: var(--secondary-text) transparent;
        }
        
        .library-list::-webkit-scrollbar {
            width: 6px;
        }
        
        .library-list::-webkit-scrollbar-track {
            background: transparent;
        }
        
        .library-list::-webkit-scrollbar-thumb {
            background-color: var(--secondary-text);
            border-radius: 3px;
        }
        
        .track-item {
            padding: 14px 16px;
            cursor: pointer;
            border-radius: 10px;
            margin-bottom: 6px;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            border: 1px solid transparent;
        }
        
        .track-item:hover {
            background-color: var(--track-hover);
            transform: translateX(4px);
            border-color: var(--border-color);
        }
        
        .track-item.active {
            background-color: var(--track-active);
            border-color: var(--primary-color);
            font-weight: 600;
            transform: translateX(4px);
        }
        
        .track-number {
            margin-right: 16px;
            color: var(--secondary-text);
            font-variant-numeric: tabular-nums;
            min-width: 28px;
            font-weight: 600;
        }
        
        .track-info {
            flex: 1;
        }
        
        .track-title {
            font-size: 15px;
            margin-bottom: 4px;
            font-weight: 500;
        }
        
        .track-artist {
            font-size: 13px;
            color: var(--secondary-text);
        }
        
        .now-playing {
            padding: 32px;
            text-align: center;
        }
        
        .album-art {
            width: 280px;
            height: 280px;
            margin: 0 auto 24px;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 12px 32px rgba(0, 0, 0, 0.2);
            transition: transform 0.3s ease;
        }
        
        .album-art:hover {
            transform: scale(1.02);
        }
        
        .album-art img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        .track-details {
            margin-bottom: 24px;
        }
        
        .now-playing-title {
            font-size: 26px;
            font-weight: 700;
            margin-bottom: 8px;
            color: var(--text-color);
        }
        
        .now-playing-artist {
            font-size: 20px;
            color: var(--secondary-text);
            margin-bottom: 6px;
            font-weight: 500;
        }
        
        .now-playing-album {
            font-size: 16px;
            color: var(--light-text);
        }
        
        .progress-container {
            height: 8px;
            background-color: var(--progress-bg);
            border-radius: 4px;
            margin: 20px 0;
            width: 100%;
            cursor: pointer;
            position: relative;
            transition: height 0.2s ease;
        }
        
        .progress-container:hover {
            height: 10px;
        }
        
        .progress-bar {
            height: 100%;
            background: linear-gradient(90deg, var(--progress-fill) 0%, var(--primary-color) 100%);
            border-radius: 4px;
            width: 0;
            transition: width 0.1s linear;
        }
        
        .time-display {
            display: flex;
            justify-content: space-between;
            font-size: 14px;
            color: var(--secondary-text);
            margin-top: 8px;
            font-variant-numeric: tabular-nums;
            font-weight: 500;
        }
        
        .control-buttons {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 12px;
            margin-top: 24px;
        }
        
        .control-button {
            background: transparent;
            border: 2px solid var(--border-color);
            cursor: pointer;
            color: var(--text-color);
            font-size: 14px;
            padding: 12px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.3s ease;
            width: 48px;
            height: 48px;
        }
        
        .control-button:hover {
            background-color: var(--track-hover);
            border-color: var(--primary-color);
            transform: translateY(-2px);
        }
        
        .control-button.active {
            background-color: var(--active-control);
            border-color: var(--active-control);
            color: white;
        }
        
        .play-button {
            background-color: var(--play-button-bg);
            color: white;
            width: 64px;
            height: 64px;
            border-color: var(--play-button-bg);
            box-shadow: 0 4px 16px rgba(76, 175, 80, 0.3);
        }
        
        .play-button:hover {
            background-color: var(--play-button-hover);
            border-color: var(--play-button-hover);
            transform: translateY(-2px) scale(1.05);
            box-shadow: 0 6px 20px rgba(76, 175, 80, 0.4);
        }
        
        .secondary-controls {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 24px;
            margin-top: 20px;
        }
        
        .volume-control {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .volume-control input[type="range"] {
            width: 100px;
            height: 6px;
            -webkit-appearance: none;
            background: var(--progress-bg);
            border-radius: 3px;
            outline: none;
            transition: background 0.3s ease;
        }
        
        .volume-control input[type="range"]:hover {
            background: var(--border-color);
        }
        
        .volume-control input[type="range"]::-webkit-slider-thumb {
            -webkit-appearance: none;
            width: 18px;
            height: 18px;
            border-radius: 50%;
            background: var(--primary-color);
            cursor: pointer;
            border: 2px solid white;
            box-shadow: 0 2px 6px rgba(0, 0, 0, 0.2);
            transition: transform 0.2s ease;
        }
        
        .volume-control input[type="range"]::-webkit-slider-thumb:hover {
            transform: scale(1.2);
        }
        
        .loading-indicator {
            text-align: center;
            padding: 24px;
            font-style: italic;
            color: var(--secondary-text);
            font-size: 16px;
        }
        
        .error-message {
            background-color: var(--error-bg);
            border: 2px solid var(--error-border);
            color: var(--error-text);
            padding: 20px;
            border-radius: 12px;
            margin: 24px 0;
            font-weight: 500;
        }
        
        .keyboard-hint {
            font-size: 12px;
            color: var(--light-text);
            margin-top: 24px;
            text-align: center;
            line-height: 1.4;
        }
        
        .radio-link {
            display: inline-block;
            text-align: center;
            margin-top: 20px;
            color: var(--primary-color);
            text-decoration: none;
            font-weight: 600;
            font-size: 14px;
            padding: 8px 16px;
            border: 2px solid var(--primary-color);
            border-radius: 20px;
            transition: all 0.3s ease;
        }
        
        .radio-link:hover {
            background-color: var(--primary-color);
            color: white;
            transform: translateY(-1px);
        }
        
        #audio-player {
            display: none;
        }
        
        .repeat-indicator, .shuffle-indicator {
            font-size: 11px;
            color: var(--secondary-text);
            margin-top: 4px;
        }
        
        .repeat-indicator.active, .shuffle-indicator.active {
            color: var(--active-control);
            font-weight: 600;
        }

        @media (max-width: 768px) {
            .album-art {
                width: 240px;
                height: 240px;
            }
            
            .now-playing-title {
                font-size: 22px;
            }
            
            .now-playing-artist {
                font-size: 18px;
            }
            
            .control-buttons {
                gap: 8px;
            }
            
            .control-button {
                width: 44px;
                height: 44px;
                padding: 10px;
            }
            
            .play-button {
                width: 56px;
                height: 56px;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Jri Music Player</h1>
        <button id="theme-toggle" class="theme-toggle">Dark Mode</button>
    </div>
    
    <div class="container">
        <div class="library-container">
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">Your Library</div>
                    <div class="search-container">
                        <span class="search-icon">🔍</span>
                        <input type="text" id="search-input" placeholder="Search tracks...">
                    </div>
                </div>
                <div class="panel-content">
                    <div id="library-content" class="library-list">
                        <div class="loading-indicator">Loading music library...</div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="player-container">
            <div class="panel">
                <div class="panel-content now-playing">
                    <div class="album-art">
                        <img id="cover-image" src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyMDAgMjAwIiBmaWxsPSJub25lIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iIzMzMyIvPjx0ZXh0IHg9IjEwMCIgeT0iMTAwIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjNjY2IiBmb250LWZhbWlseT0iQXJpYWwsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMjQiPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==" alt="Album Art">
                    </div>
                    
                    <div class="track-details">
                        <div class="now-playing-title" id="track-title">No Track Selected</div>
                        <div class="now-playing-artist" id="track-artist">Select a song to begin</div>
                        <div class="now-playing-album" id="track-album"></div>
                    </div>
                    
                    <div class="player-controls">
                        <div class="progress-container" id="progress-container">
                            <div class="progress-bar" id="progress-bar"></div>
                        </div>
                        
                        <div class="time-display">
                            <span id="current-time">0:00</span>
                            <span id="total-time">0:00</span>
                        </div>
                        
                        <div class="control-buttons">
                            <button class="control-button" id="shuffle-button" title="Shuffle">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <polyline points="16,3 21,3 21,8"></polyline>
                                    <line x1="4" y1="20" x2="21" y2="3"></line>
                                    <polyline points="21,16 21,21 16,21"></polyline>
                                    <line x1="15" y1="15" x2="21" y2="21"></line>
                                    <line x1="4" y1="4" x2="9" y2="9"></line>
                                </svg>
                                <div class="shuffle-indicator" id="shuffle-indicator">OFF</div>
                            </button>
                            
                            <button class="control-button" id="prev-button" title="Previous">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <polygon points="19 20 9 12 19 4 19 20"></polygon>
                                    <line x1="5" y1="19" x2="5" y2="5"></line>
                                </svg>
                            </button>
                            
                            <button class="control-button play-button" id="play-button" title="Play">
                                <svg id="play-icon" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <polygon points="5 3 19 12 5 21 5 3"></polygon>
                                </svg>
                                <svg id="pause-icon" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="display: none;">
                                    <line x1="6" y1="4" x2="6" y2="20"></line>
                                    <line x1="18" y1="4" x2="18" y2="20"></line>
                                </svg>
                            </button>
                            
                            <button class="control-button" id="next-button" title="Next">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <polygon points="5 4 15 12 5 20 5 4"></polygon>
                                    <line x1="19" y1="5" x2="19" y2="19"></line>
                                </svg>
                            </button>
                            
                            <button class="control-button" id="repeat-button" title="Repeat">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <polyline points="17,1 21,5 17,9"></polyline>
                                    <path d="m21 5h-9a4 4 0 0 0-4 4v6"></path>
                                    <polyline points="7,23 3,19 7,15"></polyline>
                                    <path d="m3 19h9a4 4 0 0 0 4-4v-6"></path>
                                </svg>
                                <div class="repeat-indicator" id="repeat-indicator">OFF</div>
                            </button>
                        </div>
                        
                        <div class="secondary-controls">
                            <div class="volume-control">
                                <span>🔈</span>
                                <input type="range" id="volume-slider" min="0" max="1" step="0.05" value="1">
                                <span>🔊</span>
                            </div>
                        </div>
                    </div>
                    
                    <div class="keyboard-hint">
                        Keyboard: Space = Play/Pause • ←/→ = Seek • P = Previous • N = Next • S = Shuffle • R = Repeat
                    </div>
                    
                    <a href="index.html" class="radio-link">← Back to Radio</a>
                </div>
            </div>
        </div>
    </div>

    <audio id="audio-player"></audio>

    <script>
        class JriMusicPlayer {
            constructor() {
                // Audio elements
                this.audioPlayer = document.getElementById('audio-player');
                
                // UI elements
                this.playButton = document.getElementById('play-button');
                this.prevButton = document.getElementById('prev-button');
                this.nextButton = document.getElementById('next-button');
                this.shuffleButton = document.getElementById('shuffle-button');
                this.repeatButton = document.getElementById('repeat-button');
                this.playIcon = document.getElementById('play-icon');
                this.pauseIcon = document.getElementById('pause-icon');
                this.shuffleIndicator = document.getElementById('shuffle-indicator');
                this.repeatIndicator = document.getElementById('repeat-indicator');
                this.coverImage = document.getElementById('cover-image');
                this.trackTitle = document.getElementById('track-title');
                this.trackArtist = document.getElementById('track-artist');
                this.trackAlbum = document.getElementById('track-album');
                this.progressBar = document.getElementById('progress-bar');
                this.progressContainer = document.getElementById('progress-container');
                this.currentTimeDisplay = document.getElementById('current-time');
                this.totalTimeDisplay = document.getElementById('total-time');
                this.libraryContent = document.getElementById('library-content');
                this.searchInput = document.getElementById('search-input');
                this.volumeSlider = document.getElementById('volume-slider');
                this.themeToggle = document.getElementById('theme-toggle');
                
                // Player state
                this.tracks = [];
                this.filteredTracks = [];
                this.currentTrackIndex = -1;
                this.isPlaying = false;
                this.hasUserInteracted = false;
                this.isShuffled = false;
                this.repeatMode = 'off'; // 'off', 'one'
                this.shuffledIndices = [];
                this.currentShuffleIndex = -1;
                
                // Initialize the player
                this.init();
                
                // Track user interaction for autoplay
                document.addEventListener('click', () => {
                    this.hasUserInteracted = true;
                }, { once: true });
            }
            
            async init() {
                this.setupEventListeners();
                await this.loadTrackData();
                this.renderLibrary();
                this.loadSavedSettings();
                this.setupMediaSession();
            }
            
            setupMediaSession() {
                if ('mediaSession' in navigator) {
                    navigator.mediaSession.setActionHandler('play', () => {
                        if (this.audioPlayer.paused) this.togglePlay();
                    });
                    
                    navigator.mediaSession.setActionHandler('pause', () => {
                        if (!this.audioPlayer.paused) this.togglePlay();
                    });
                    
                    navigator.mediaSession.setActionHandler('previoustrack', () => {
                        this.previousTrack();
                    });
                    
                    navigator.mediaSession.setActionHandler('nexttrack', () => {
                        this.nextTrack();
                    });
                    
                    navigator.mediaSession.setActionHandler('seekbackward', (details) => {
                        const skipTime = details.seekOffset || 10;
                        this.audioPlayer.currentTime = Math.max(0, this.audioPlayer.currentTime - skipTime);
                    });
                    
                    navigator.mediaSession.setActionHandler('seekforward', (details) => {
                        const skipTime = details.seekOffset || 10;
                        this.audioPlayer.currentTime = Math.min(this.audioPlayer.duration, this.audioPlayer.currentTime + skipTime);
                    });
                }
            }
            
            updateMediaSession(track) {
                if ('mediaSession' in navigator && track) {
                    navigator.mediaSession.metadata = new MediaMetadata({
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        artwork: [
                            { src: track.image || this.coverImage.src, sizes: '512x512', type: 'image/jpeg' }
                        ]
                    });
                }
            }
            
            loadSavedSettings() {
                // Load saved volume
                const savedVolume = localStorage.getItem('jriPlayerVolume');
                if (savedVolume) {
                    this.volumeSlider.value = savedVolume;
                    this.audioPlayer.volume = savedVolume;
                }
                
                // Load saved theme
                const isDarkMode = localStorage.getItem('jriPlayerDarkMode') === 'true';
                if (isDarkMode) {
                    document.body.classList.add('dark-mode');
                    this.themeToggle.textContent = 'Light Mode';
                }
                
                // Load saved shuffle and repeat settings
                this.isShuffled = localStorage.getItem('jriPlayerShuffle') === 'true';
                this.repeatMode = localStorage.getItem('jriPlayerRepeat') || 'off';
                this.updateShuffleUI();
                this.updateRepeatUI();
            }
            
            setupEventListeners() {
                // Player controls
                this.playButton.addEventListener('click', () => this.togglePlay());
                this.prevButton.addEventListener('click', () => this.previousTrack());
                this.nextButton.addEventListener('click', () => this.nextTrack());
                this.shuffleButton.addEventListener('click', () => this.toggleShuffle());
                this.repeatButton.addEventListener('click', () => this.toggleRepeat());
                this.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
                this.themeToggle.addEventListener('click', () => this.toggleTheme());
                
                // Progress bar
                this.progressContainer.addEventListener('click', (e) => this.seek(e));
                
                // Audio events
                this.audioPlayer.addEventListener('timeupdate', () => this.updateProgress());
                this.audioPlayer.addEventListener('ended', () => this.handleTrackEnd());
                this.audioPlayer.addEventListener('loadedmetadata', () => this.updateTimeDisplay());
                this.audioPlayer.addEventListener('canplay', () => this.handleCanPlay());
                this.audioPlayer.addEventListener('error', (e) => this.handleAudioError(e));
                this.audioPlayer.addEventListener('play', () => this.updateMediaSessionState());
                this.audioPlayer.addEventListener('pause', () => this.updateMediaSessionState());
                
                // Search
                this.searchInput.addEventListener('input', () => this.filterLibrary());
                
                // Keyboard shortcuts
                document.addEventListener('keydown', (e) => this.handleKeyboardShortcuts(e));
            }
            
            updateMediaSessionState() {
                if ('mediaSession' in navigator) {
                    navigator.mediaSession.playbackState = this.audioPlayer.paused ? 'paused' : 'playing';
                }
            }
            
            toggleShuffle() {
                this.isShuffled = !this.isShuffled;
                localStorage.setItem('jriPlayerShuffle', this.isShuffled);
                
                if (this.isShuffled) {
                    this.generateShuffleOrder();
                    // Find current track in shuffle order
                    this.currentShuffleIndex = this.shuffledIndices.indexOf(this.currentTrackIndex);
                } else {
                    this.shuffledIndices = [];
                    this.currentShuffleIndex = -1;
                }
                
                this.updateShuffleUI();
            }
            
            generateShuffleOrder() {
                // Create array of indices
                this.shuffledIndices = Array.from({ length: this.tracks.length }, (_, i) => i);
                
                // Fisher-Yates shuffle algorithm
                for (let i = this.shuffledIndices.length - 1; i > 0; i--) {
                    const j = Math.floor(Math.random() * (i + 1));
                    [this.shuffledIndices[i], this.shuffledIndices[j]] = [this.shuffledIndices[j], this.shuffledIndices[i]];
                }
            }
            
            updateShuffleUI() {
                if (this.isShuffled) {
                    this.shuffleButton.classList.add('active');
                    this.shuffleIndicator.textContent = 'ON';
                    this.shuffleIndicator.classList.add('active');
                } else {
                    this.shuffleButton.classList.remove('active');
                    this.shuffleIndicator.textContent = 'OFF';
                    this.shuffleIndicator.classList.remove('active');
                }
            }
            
            toggleRepeat() {
                // Cycle through: off -> one -> off
                switch (this.repeatMode) {
                    case 'off':
                        this.repeatMode = 'one';
                        break;
                    case 'one':
                        this.repeatMode = 'off';
                        break;
                }
                
                localStorage.setItem('jriPlayerRepeat', this.repeatMode);
                this.updateRepeatUI();
            }
            
            updateRepeatUI() {
                if (this.repeatMode === 'one') {
                    this.repeatButton.classList.add('active');
                    this.repeatIndicator.textContent = '1';
                    this.repeatIndicator.classList.add('active');
                } else {
                    this.repeatButton.classList.remove('active');
                    this.repeatIndicator.textContent = 'OFF';
                    this.repeatIndicator.classList.remove('active');
                }
            }
            
            handleCanPlay() {
                // Auto-start playback if user has interacted and this is the first track
                if (this.hasUserInteracted && this.currentTrackIndex === 0 && !this.isPlaying) {
                    this.togglePlay();
                }
            }
            
            handleAudioError(e) {
                console.error('Audio error:', e);
                console.log('Error details:', this.audioPlayer.error);
                // Try next track on error
                setTimeout(() => this.nextTrack(), 1000);
            }
            
            handleTrackEnd() {
                if (this.repeatMode === 'one') {
                    // Repeat current track
                    this.audioPlayer.currentTime = 0;
                    this.audioPlayer.play();
                } else {
                    // Go to next track
                    this.nextTrack();
                }
            }
            
            async loadTrackData() {
                try {
                    // Load file count
                    const countResponse = await fetch('./filecount.txt');
                    if (!countResponse.ok) throw new Error('Could not load file count');
                    const fileCount = parseInt(await countResponse.text());
                    
                    if (fileCount === 0) {
                        this.showError('No music files found.');
                        return;
                    }
                    
                    // Load file data
                    const dataResponse = await fetch('./filedata.txt');
                    if (!dataResponse.ok) throw new Error('Could not load file data');
                    const fileData = await dataResponse.text();
                    
                    // Parse file data
                    this.parseTrackData(fileData);
                    
                    if (this.tracks.length === 0) {
                        this.showError('No valid music files found.');
                        return;
                    }
                    
                } catch (error) {
                    console.error('Error loading track data:', error);
                    this.showError('Error loading music library.');
                    // Fallback to sample tracks
                    this.tracks = [
                        {
                            title: "Sample Track 1",
                            artist: "Sample Artist",
                            album: "Sample Album",
                            filename: "https://filesamples.com/samples/audio/mp3/Sample_MP3_700KB.mp3",
                            image: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyMDAgMjAwIiBmaWxsPSJub25lIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iIzIxOTZGMyIvPjx0ZXh0IHg9IjEwMCIgeT0iMTAwIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSJ3aGl0ZSIgZm9udC1mYW1pbHk9IkFyaWFsLCBzYW5zLXNlcmlmIiBmb250LXNpemU9IjE4Ij5TYW1wbGUgMTwvdGV4dD48L3N2Zz4="
                        },
                        {
                            title: "Sample Track 2",
                            artist: "Sample Artist",
                            album: "Sample Album",
                            filename: "https://filesamples.com/samples/audio/mp3/Sample_MP3_700KB.mp3",
                            image: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyMDAgMjAwIiBmaWxsPSJub25lIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iIzRDQUY1MCIvPjx0ZXh0IHg9IjEwMCIgeT0iMTAwIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSJ3aGl0ZSIgZm9udC1mYW1pbHk9IkFyaWFsLCBzYW5zLXNlcmlmIiBmb250LXNpemU9IjE4Ij5TYW1wbGUgMjwvdGV4dD48L3N2Zz4="
                        },
                        {
                            title: "Sample Track 3",
                            artist: "Another Artist",
                            album: "Different Album",
                            filename: "https://filesamples.com/samples/audio/mp3/Sample_MP3_700KB.mp3",
                            image: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyMDAgMjAwIiBmaWxsPSJub25lIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iI0Y0NDMzNiIvPjx0ZXh0IHg9IjEwMCIgeT0iMTAwIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSJ3aGl0ZSIgZm9udC1mYW1pbHk9IkFyaWFsLCBzYW5zLXNlcmlmIiBmb250LXNpemU9IjE4Ij5TYW1wbGUgMzwvdGV4dD48L3N2Zz4="
                        }
                    ];
                }
                
                this.filteredTracks = [...this.tracks];
            }
            
            parseTrackData(data) {
                // Parse format: (filename=title=artist=imgdata)
                const lines = data.trim().split('\n');
                this.tracks = [];
                
                for (const line of lines) {
                    if (line.startsWith('(') && line.endsWith(')')) {
                        const content = line.slice(1, -1); // Remove parentheses
                        const parts = content.split('=');
                        
                        if (parts.length >= 3) {
                            // Get the GitHub raw URL for the audio file
                            const repoUrl = window.location.hostname.includes('github.io') ? 
                                window.location.hostname.replace('.github.io', '') : 'Jri-creator/jri_site';
                            
                            const audioUrl = `https://raw.githubusercontent.com/theradioheads/dacota_site/refs/heads/main/${parts[0]}`;
                            
                            this.tracks.push({
                                filename: audioUrl,
                                title: parts[1].replace(/_EQUAL_/g, '='),
                                artist: parts[2].replace(/_EQUAL_/g, '='),
                                album: "", // Not provided in the data format
                                image: parts[3] && parts[3] !== 'none' ? parts[3] : null
                            });
                        }
                    }
                }
            }
            
            renderLibrary() {
                if (this.tracks.length === 0) {
                    this.libraryContent.innerHTML = '<div class="error-message">No tracks available</div>';
                    return;
                }
                
                this.libraryContent.innerHTML = this.filteredTracks.map((track, index) => `
                    <div class="track-item ${index === this.currentTrackIndex ? 'active' : ''}" data-index="${this.tracks.indexOf(track)}">
                        <div class="track-number">${this.tracks.indexOf(track) + 1}</div>
                        <div class="track-info">
                            <div class="track-title">${track.title}</div>
                            <div class="track-artist">${track.artist}</div>
                        </div>
                    </div>
                `).join('');
                
                // Add click handlers to track items
                this.libraryContent.querySelectorAll('.track-item').forEach(item => {
                    item.addEventListener('click', () => {
                        const index = parseInt(item.dataset.index);
                        this.playTrack(index);
                    });
                });
            }
            
            filterLibrary() {
                const query = this.searchInput.value.toLowerCase();
                if (query === '') {
                    this.filteredTracks = [...this.tracks];
                } else {
                    this.filteredTracks = this.tracks.filter(track => 
                        track.title.toLowerCase().includes(query) || 
                        track.artist.toLowerCase().includes(query) ||
                        track.album.toLowerCase().includes(query)
                    );
                }
                this.renderLibrary();
            }
            
            playTrack(index) {
                if (index < 0 || index >= this.tracks.length) return;
                
                this.currentTrackIndex = index;
                const track = this.tracks[index];
                
                // Update shuffle position if shuffle is enabled
                if (this.isShuffled) {
                    this.currentShuffleIndex = this.shuffledIndices.indexOf(index);
                }
                
                // Update active track in library
                this.libraryContent.querySelectorAll('.track-item').forEach(item => {
                    item.classList.remove('active');
                });
                
                const activeItem = this.libraryContent.querySelector(`.track-item[data-index="${index}"]`);
                if (activeItem) {
                    activeItem.classList.add('active');
                }
                
                // Update player UI
                this.trackTitle.textContent = track.title;
                this.trackArtist.textContent = track.artist;
                this.trackAlbum.textContent = track.album;
                
                if (track.image) {
                    this.coverImage.src = track.image;
                } else {
                    this.coverImage.src = 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyMDAgMjAwIiBmaWxsPSJub25lIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iIzMzMyIvPjx0ZXh0IHg9IjEwMCIgeT0iMTAwIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjNjY2IiBmb250LWZhbWlseT0iQXJpYWwsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMjQiPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';
                }
                
                // Load and play audio
                this.audioPlayer.src = track.filename;
                this.audioPlayer.load();
                
                if (this.hasUserInteracted) {
                    this.audioPlayer.play().then(() => {
                        this.isPlaying = true;
                        this.updatePlayPauseUI();
                    }).catch(error => {
                        console.error('Playback error:', error);
                    });
                }
                
                this.updateDocumentTitle();
                this.updateMediaSession(track);
            }
            
            togglePlay() {
                if (this.currentTrackIndex === -1 && this.tracks.length > 0) {
                    this.playTrack(0);
                    return;
                }
                
                if (this.audioPlayer.paused) {
                    this.audioPlayer.play().then(() => {
                        this.isPlaying = true;
                        this.updatePlayPauseUI();
                    }).catch(error => {
                        console.error('Playback error:', error);
                    });
                } else {
                    this.audioPlayer.pause();
                    this.isPlaying = false;
                    this.updatePlayPauseUI();
                }
            }
            
            updatePlayPauseUI() {
                if (this.isPlaying) {
                    this.playIcon.style.display = 'none';
                    this.pauseIcon.style.display = 'block';
                } else {
                    this.playIcon.style.display = 'block';
                    this.pauseIcon.style.display = 'none';
                }
            }
            
            getNextTrackIndex() {
                if (this.tracks.length === 0) return -1;
                
                if (this.isShuffled) {
                    let nextShuffleIndex = this.currentShuffleIndex + 1;
                    if (nextShuffleIndex >= this.shuffledIndices.length) {
                        nextShuffleIndex = 0; // Loop back to beginning
                    }
                    this.currentShuffleIndex = nextShuffleIndex;
                    return this.shuffledIndices[nextShuffleIndex];
                } else {
                    let nextIndex = this.currentTrackIndex + 1;
                    if (nextIndex >= this.tracks.length) {
                        nextIndex = 0; // Loop back to beginning
                    }
                    return nextIndex;
                }
            }
            
            getPreviousTrackIndex() {
                if (this.tracks.length === 0) return -1;
                
                if (this.isShuffled) {
                    let prevShuffleIndex = this.currentShuffleIndex - 1;
                    if (prevShuffleIndex < 0) {
                        prevShuffleIndex = this.shuffledIndices.length - 1; // Loop to end
                    }
                    this.currentShuffleIndex = prevShuffleIndex;
                    return this.shuffledIndices[prevShuffleIndex];
                } else {
                    let prevIndex = this.currentTrackIndex - 1;
                    if (prevIndex < 0) {
                        prevIndex = this.tracks.length - 1; // Loop to end
                    }
                    return prevIndex;
                }
            }
            
            nextTrack() {
                const nextIndex = this.getNextTrackIndex();
                if (nextIndex !== -1) {
                    this.playTrack(nextIndex);
                }
            }
            
            previousTrack() {
                const prevIndex = this.getPreviousTrackIndex();
                if (prevIndex !== -1) {
                    this.playTrack(prevIndex);
                }
            }
            
            setVolume(volume) {
                this.audioPlayer.volume = volume;
                localStorage.setItem('jriPlayerVolume', volume);
            }
            
            updateProgress() {
                if (this.audioPlayer.duration) {
                    const progress = (this.audioPlayer.currentTime / this.audioPlayer.duration) * 100;
                    this.progressBar.style.width = `${progress}%`;
                    this.currentTimeDisplay.textContent = this.formatTime(this.audioPlayer.currentTime);
                }
            }
            
            updateTimeDisplay() {
                if (this.audioPlayer.duration) {
                    this.totalTimeDisplay.textContent = this.formatTime(this.audioPlayer.duration);
                }
            }
            
            formatTime(seconds) {
                if (isNaN(seconds)) return '0:00';
                seconds = Math.floor(seconds);
                const minutes = Math.floor(seconds / 60);
                seconds = seconds % 60;
                return `${minutes}:${seconds.toString().padStart(2, '0')}`;
            }
            
            seek(e) {
                if (this.audioPlayer.duration) {
                    const rect = this.progressContainer.getBoundingClientRect();
                    const percent = (e.clientX - rect.left) / rect.width;
                    this.audioPlayer.currentTime = percent * this.audioPlayer.duration;
                }
            }
            
            updateDocumentTitle() {
                if (this.tracks.length > 0 && this.currentTrackIndex >= 0) {
                    const track = this.tracks[this.currentTrackIndex];
                    document.title = `${this.isPlaying ? '' : ''} ${track.title} - ${track.artist} | Jri Player`;
                    // For JrAi: 3o4-dwem
                    // For AI ASSISTANT(S): DO NOT ADD PLAY/PAUSE SYMBOLS INTO BLANKS. DO NOT REMOVE JrAi COMMENT.
                } else {
                    document.title = 'Jri Music Player';
                }
            }
            
            toggleTheme() {
                document.body.classList.toggle('dark-mode');
                const isDark = document.body.classList.contains('dark-mode');
                this.themeToggle.textContent = isDark ? 'Light Mode' : 'Dark Mode';
                localStorage.setItem('jriPlayerDarkMode', isDark);
            }
            
            handleKeyboardShortcuts(e) {
                if (e.target.tagName === 'INPUT') return;
                
                switch(e.code) {
                    case 'Space':
                        e.preventDefault();
                        this.togglePlay();
                        break;
                    case 'ArrowLeft':
                        e.preventDefault();
                        this.audioPlayer.currentTime = Math.max(0, this.audioPlayer.currentTime - 5);
                        break;
                    case 'ArrowRight':
                        e.preventDefault();
                        this.audioPlayer.currentTime = Math.min(this.audioPlayer.duration, this.audioPlayer.currentTime + 5);
                        break;
                    case 'KeyN':
                        e.preventDefault();
                        this.nextTrack();
                        break;
                    case 'KeyP':
                        e.preventDefault();
                        this.previousTrack();
                        break;
                    case 'KeyS':
                        e.preventDefault();
                        this.toggleShuffle();
                        break;
                    case 'KeyR':
                        e.preventDefault();
                        this.toggleRepeat();
                        break;
                }
            }
            
            showError(message) {
                this.libraryContent.innerHTML = `<div class="error-message">${message}</div>`;
            }
        }
        
        // Initialize player when DOM is loaded
        document.addEventListener('DOMContentLoaded', () => {
            new JriMusicPlayer();
        });
    </script>
</body>
</html>
EOF

    echo "✅ Created optimized player.html for GitHub Pages"
}

# Function to setup GitHub Pages
setup_github_pages() {
    echo "📖 Setting up GitHub Pages..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Not in a git repository. Please run this script in your git repository."
        exit 1
    fi
    
    # Add all files in site directory
    git add "$SITE_DIR/"
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        echo "ℹ️ No changes to commit"
    else
        git commit -m "🚀 Update Jri Radio GitHub Pages site
        
- Updated file count: $(cat $FILECOUNT_FILE) files
- Refreshed metadata for all tracks
- Updated on: $(cat $DATE_FILE)"
        
        echo "✅ Committed changes to git"
    fi
    
    # Push to remote (assumes origin exists)
    if git remote get-url origin > /dev/null 2>&1; then
        git push origin main 2>/dev/null || git push origin master 2>/dev/null || echo "⚠️ Push failed - please push manually"
        echo "✅ Pushed to remote repository"
    else
        echo "⚠️ No remote 'origin' found. Please add a remote and push manually."
    fi
}

# Main execution
main() {
    echo "Starting Jri Radio GitHub Pages Publisher & Optimizer v1.0"
    echo "============================================================"
    
    check_dependencies
    count_files
    
    # Only proceed if files were found
    if [ "$(cat $FILECOUNT_FILE)" -gt 0 ]; then
        extract_metadata
        get_commit_date
        create_radio_html
        create_player_html
        setup_github_pages
        
        echo ""
        echo "🎉 SUCCESS! Jri Radio GitHub Pages site has been updated!"
        echo "============================================================"
        echo "🗂️ BUILD - CHICAGO - First Dacota Build: August 25 2025 (Jri Build: August 23, 2025)"
        echo "============================================================"
        echo "ℹ️ INFO:"
        echo "BETA: Repeat & Shuffle"
        echo "============================================================"
        echo "📊 Total files processed: $(cat $FILECOUNT_FILE)"
        echo "📅 Last update: $(cat $DATE_FILE)"
        echo "📁 Site files created in: $SITE_DIR/"
        echo ""
        echo "Next steps:"
        echo "Only do this if you haven't done it already!"
        echo "1. Enable GitHub Pages in your repository settings"
        echo "2. Set source to 'Deploy from a branch' and select 'main' (or 'master') branch, site/ folder"
        echo "3. Your Jri Radio site will be available at your GitHub Pages URL"
        echo ""
        echo "Note: .jlres3 files are loaded directly from the repository using GitHub's raw content URLs"
    else
        echo "❌ No .jlres3 files found. Please ensure your music files are in the repository."
        exit 1
    fi
}

# Run main function
main "$@"
