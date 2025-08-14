#!/bin/bash

# GitHub Pages Publisher & Optimizer Script for Dacota Radio
# This script processes .jlres3 files, extracts metadata, and sets up GitHub Pages

set -e  # Exit on any error

echo "🚀 Starting Dacota Radio GitHub Pages Publisher & Optimizer"

# Configuration
SITE_DIR="site"
FILECOUNT_FILE="$SITE_DIR/filecount.txt"
FILEDATA_FILE="$SITE_DIR/filedata.txt"
DATE_FILE="$SITE_DIR/date.txt"
INDEX_FILE="$SITE_DIR/index.html"

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

# Function to copy .jlres3 files as .mp3 for web playback
copy_audio_files() {
    echo "🎵 Copying .jlres3 files as .mp3 for web playback..."
    
    local copied=0
    
    # Find all .jlres3 files and copy them with .mp3 extension to site directory
    while IFS= read -r -d '' jlres3_file; do
        local filename=$(basename "$jlres3_file")
        local target_file="$SITE_DIR/${filename}.mp3"
        
        # Copy the file with .mp3 extension for web playback
        cp "$jlres3_file" "$target_file"
        copied=$((copied + 1))
        
        echo "Copied: $filename → ${filename}.mp3"
        
    done < <(find . -name "*.jlres3" -type f -print0)
    
    echo "✅ Copied $copied audio files for web playback"
}
# Function to get commit date
get_commit_date() {
    echo "📅 Getting commit date..."
    
    # Get the current commit date in ISO format
    local commit_date=$(git log -1 --format="%cI" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$commit_date" > "$DATE_FILE"
    
    echo "✅ Commit date saved to $DATE_FILE: $commit_date"
}

# Function to create optimized index.html for GitHub Pages
create_index_html() {
    echo "🌐 Creating/updating index.html for GitHub Pages..."
    
    cat > "$INDEX_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dacota Radio</title>
    <style>
        :root {
            --bg-color: #74b9ff;
            --container-bg: #fff;
            --text-color: #333;
            --secondary-text: #777;
            --light-text: #999;
            --play-button-bg: #4CAF50;
            --play-button-hover: #45a049;
            --next-button-bg: #2196F3;
            --next-button-hover: #0b7dda;
            --progress-bg: #ddd;
            --progress-fill: #4CAF50;
            --shadow-color: rgba(0, 0, 0, 0.1);
            --error-bg: #ffebee;
            --error-border: #f44336;
            --error-text: #c62828;
        }
        
        body.dark-mode {
            --bg-color: #003060;
            --container-bg: #1e1e1e;
            --text-color: #e0e0e0;
            --secondary-text: #b0b0b0;
            --light-text: #909090;
            --play-button-bg: #388e3c;
            --play-button-hover: #2e7d32;
            --next-button-bg: #1976d2;
            --next-button-hover: #1565c0;
            --progress-bg: #424242;
            --progress-fill: #4CAF50;
            --shadow-color: rgba(0, 0, 0, 0.3);
            --error-bg: #2d1b1b;
            --error-border: #d32f2f;
            --error-text: #ef5350;
        }
        
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: var(--bg-color);
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
        
        .play-button, .next-button {
            color: white;
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
        
        .next-button {
            background-color: var(--next-button-bg);
        }
        
        .play-button:hover {
            background-color: var(--play-button-hover);
        }
        
        .next-button:hover {
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
        
        #audio-player {
            display: none;
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
                <div class="volume-control">
                    <input type="range" id="volume-slider" min="0" max="1" step="0.05" value="1">
                </div>
            </div>
        </div>
    </div>

    <script>
        // GitHub Pages optimized version of Dacota Radio
        class JriRadioPlayer {
            constructor() {
                this.audioPlayer = document.getElementById('audio-player');
                this.playButton = document.getElementById('play-button');
                this.nextButton = document.getElementById('next-button');
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
                this.currentTrackIndex = 0;
                this.isPlaying = false;
                this.hasUserInteracted = false;
                
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
                this.loadTrack(0);
                this.loadSavedSettings();
            }
            
            loadSavedSettings() {
                // Load saved volume
                const savedVolume = localStorage.getItem('jriRadioVolume');
                if (savedVolume) {
                    this.volumeSlider.value = savedVolume;
                    this.audioPlayer.volume = savedVolume;
                }
                
                // Load saved theme
                const isDarkMode = localStorage.getItem('jriRadioDarkMode') === 'true';
                if (isDarkMode) {
                    document.body.classList.add('dark-mode');
                    this.themeToggle.textContent = 'Light Mode';
                }
            }
            
            setupEventListeners() {
                this.playButton.addEventListener('click', () => this.togglePlay());
                this.nextButton.addEventListener('click', () => this.nextTrack());
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
                    
                    // Shuffle tracks for random playback
                    this.shuffleTracks();
                    
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
            
            shuffleTracks() {
                for (let i = this.tracks.length - 1; i > 0; i--) {
                    const j = Math.floor(Math.random() * (i + 1));
                    [this.tracks[i], this.tracks[j]] = [this.tracks[j], this.tracks[i]];
                }
            }
            
            loadTrack(index) {
                if (index >= this.tracks.length) {
                    this.shuffleTracks();
                    index = 0;
                }
                
                this.currentTrackIndex = index;
                const track = this.tracks[index];
                
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
                    
                    this.audioPlayer.src = `https://raw.githubusercontent.com/Jri-creator/dacota_site/refs/heads/main/${track.filename}`;
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
                localStorage.setItem('jriRadioVolume', volume);
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
                if (this.tracks.length > 0) {
                    const track = this.tracks[this.currentTrackIndex];
                    const baseTitle = this.isPlaying ? 
                        ` ${track.title} - ${track.artist}` : 
                        ` ${track.title} - ${track.artist}`;
                    document.title = baseTitle;
                } else {
                    document.title = 'Jri Radio';
                }
            }
            
            toggleTheme() {
                document.body.classList.toggle('dark-mode');
                const isDark = document.body.classList.contains('dark-mode');
                this.themeToggle.textContent = isDark ? 'Light Mode' : 'Dark Mode';
                localStorage.setItem('jriRadioDarkMode', isDark);
            }
        }
        
        // Initialize player when DOM is loaded
        document.addEventListener('DOMContentLoaded', () => {
            new JriRadioPlayer();
        });
    </script>
</body>
</html>
EOF

    echo "✅ Created optimized index.html for GitHub Pages"
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
    
    echo "📖 GitHub Pages should be available at: https://$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | tr '[:upper:]' '[:lower:]').github.io"
}

# Main execution
main() {
    echo "Starting Dacota Radio GitHub Pages Publisher & Optimizer v1.0"
    echo "============================================================"
    
    check_dependencies
    count_files
    
    # Only proceed if files were found
    if [ "$(cat $FILECOUNT_FILE)" -gt 0 ]; then
        extract_metadata
        get_commit_date
        create_index_html
        setup_github_pages
        
        echo ""
        echo "🎉 SUCCESS! Dacota Radio GitHub Pages site has been updated!"
        echo "============================================================"
        echo "📊 Total files processed: $(cat $FILECOUNT_FILE)"
        echo "📅 Last update: $(cat $DATE_FILE)"
        echo "📁 Site files created in: $SITE_DIR/"
        echo ""
        echo "Next steps:"
        echo "Only do this is you haven't done it already!"
        echo "1. Enable GitHub Pages in your repository settings"
        echo "2. Set source to 'Deploy from a branch' and select 'main' (or 'master') branch, /site folder"
        echo "3. Your Dacota Radio site will be available at your GitHub Pages URL"
        echo ""
        echo "Note: .jlres3 files are loaded directly from the repository using GitHub's raw content URLs"
    else
        echo "❌ No .jlres3 files found. Please ensure your music files are in the repository."
        exit 1
    fi
}

# Run main function
main "$@"
