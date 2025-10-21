#!/usr/bin/python

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-present AmberELEC (https://github.com/AmberELEC)

"""
System File Sync Utility
Compares files in roms/System/* with their counterparts on the root partition
and offers to apply changes or copy files.
"""

import os
import sys
import difflib
import shutil
import hashlib
import subprocess
from pathlib import Path

try:
    import pygame
except ImportError:
    print("Error: pygame not found. Please install pygame.")
    sys.exit(1)


class Color:
    """Color palette for the UI"""
    BLACK = (0, 0, 0)
    WHITE = (255, 255, 255)
    GRAY = (128, 128, 128)
    LIGHT_GRAY = (200, 200, 200)
    DARK_GRAY = (64, 64, 64)
    GREEN = (0, 200, 0)
    RED = (200, 0, 0)
    BLUE = (0, 100, 200)
    YELLOW = (255, 200, 0)


class SystemSyncUI:
    """Pygame-based UI for system file synchronization"""
    
    def __init__(self, roms_path="/storage/roms", root_path="/"):
        pygame.init()
        
        # Display settings
        self.screen = pygame.display.set_mode((640, 480))
        pygame.display.set_caption("System File Sync")
        
        # Fonts
        try:
            self.font_large = pygame.font.Font(None, 32)
            self.font_medium = pygame.font.Font(None, 24)
            self.font_small = pygame.font.Font(None, 20)
        except:
            self.font_large = pygame.font.SysFont('arial', 32)
            self.font_medium = pygame.font.SysFont('arial', 24)
            self.font_small = pygame.font.SysFont('arial', 20)
        
        # Paths
        self.roms_path = Path(roms_path)
        self.system_path = self.roms_path / "System"
        self.root_path = Path(root_path)
        
        # State
        self.files_to_sync = []
        self.selected_index = 0
        self.scroll_offset = 0
        self.max_visible_items = 12
        self.state = "scan"  # scan, list, confirm, diff, syncing, done
        self.current_file = None
        self.diff_lines = []
        self.diff_scroll = 0
        
        self.clock = pygame.time.Clock()
        self.running = True
        
    def check_system_folder(self):
        """Check if System folder exists and scan for files"""
        if not self.system_path.exists():
            return False
        
        self.files_to_sync = []
        
        # Walk through System directory
        for root, dirs, files in os.walk(self.system_path):
            for filename in files:
                src_file = Path(root) / filename
                # Get relative path from System folder
                rel_path = src_file.relative_to(self.system_path)
                # Construct destination path on root partition
                dest_file = self.root_path / rel_path
                
                # Check if files differ
                status = self.compare_files(src_file, dest_file)
                if status != "identical":
                    self.files_to_sync.append({
                        'src': src_file,
                        'dest': dest_file,
                        'rel_path': str(rel_path),
                        'status': status,
                        'selected': True
                    })
        
        return True
    
    def compare_files(self, src, dest):
        """Compare two files and return status"""
        if not dest.exists():
            return "new"
        
        # Compare file hashes
        try:
            src_hash = self.file_hash(src)
            dest_hash = self.file_hash(dest)
            
            if src_hash == dest_hash:
                return "identical"
            else:
                return "modified"
        except Exception as e:
            return f"error: {str(e)}"
    
    def file_hash(self, filepath):
        """Calculate MD5 hash of a file"""
        hash_md5 = hashlib.md5()
        try:
            with open(filepath, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except Exception:
            return None
    
    def get_file_diff(self, src, dest):
        """Generate diff between two files"""
        try:
            if not dest.exists():
                return [f"New file: {src.name}"]
            
            with open(src, 'r', encoding='utf-8', errors='ignore') as f:
                src_lines = f.readlines()
            with open(dest, 'r', encoding='utf-8', errors='ignore') as f:
                dest_lines = f.readlines()
            
            diff = difflib.unified_diff(
                dest_lines, src_lines,
                fromfile=str(dest), tofile=str(src),
                lineterm=''
            )
            return list(diff)
        except Exception as e:
            return [f"Cannot generate diff: {str(e)}"]
    
    def sync_file(self, file_info):
        """Sync a single file"""
        try:
            src = file_info['src']
            dest = file_info['dest']
            
            # Create destination directory if needed
            dest.parent.mkdir(parents=True, exist_ok=True)
            
            # Copy file
            shutil.copy2(src, dest)
            return True
        except Exception as e:
            print(f"Error syncing {file_info['rel_path']}: {e}")
            return False
    
    def sync_selected_files(self):
        """Sync all selected files"""
        success_count = 0
        fail_count = 0
        
        for file_info in self.files_to_sync:
            if file_info['selected']:
                if self.sync_file(file_info):
                    success_count += 1
                else:
                    fail_count += 1
        
        return success_count, fail_count
    
    def draw_text(self, text, x, y, font, color=Color.WHITE, center=False):
        """Draw text on screen"""
        surface = font.render(text, True, color)
        rect = surface.get_rect()
        if center:
            rect.center = (x, y)
        else:
            rect.topleft = (x, y)
        self.screen.blit(surface, rect)
    
    def draw_scan_screen(self):
        """Draw scanning screen"""
        self.screen.fill(Color.BLACK)
        self.draw_text("System File Sync", 320, 100, self.font_large, Color.WHITE, center=True)
        self.draw_text("Scanning for files...", 320, 240, self.font_medium, Color.LIGHT_GRAY, center=True)
        
        if not self.system_path.exists():
            self.draw_text("System folder not found!", 320, 280, self.font_medium, Color.RED, center=True)
            self.draw_text(f"Expected: {self.system_path}", 320, 310, self.font_small, Color.GRAY, center=True)
            self.draw_text("Press ESC to exit", 320, 400, self.font_small, Color.GRAY, center=True)
    
    def draw_list_screen(self):
        """Draw file list screen"""
        self.screen.fill(Color.BLACK)
        
        # Header
        self.draw_text("Files to Sync", 20, 20, self.font_large, Color.WHITE)
        self.draw_text(f"{len([f for f in self.files_to_sync if f['selected']])} of {len(self.files_to_sync)} selected", 
                      620, 30, self.font_small, Color.LIGHT_GRAY, center=True)
        
        # Instructions
        y_offset = 60
        self.draw_text("UP/DOWN: Navigate  SPACE: Toggle  D: View Diff  ENTER: Sync  ESC: Exit", 
                      20, y_offset, self.font_small, Color.GRAY)
        
        # File list
        y_offset = 100
        line_height = 28
        
        visible_start = self.scroll_offset
        visible_end = min(visible_start + self.max_visible_items, len(self.files_to_sync))
        
        for i in range(visible_start, visible_end):
            file_info = self.files_to_sync[i]
            y = y_offset + (i - visible_start) * line_height
            
            # Highlight selected item
            if i == self.selected_index:
                pygame.draw.rect(self.screen, Color.DARK_GRAY, (10, y - 2, 620, line_height))
            
            # Checkbox
            checkbox_x = 20
            checkbox_size = 16
            checkbox_color = Color.GREEN if file_info['selected'] else Color.GRAY
            pygame.draw.rect(self.screen, checkbox_color, 
                           (checkbox_x, y + 4, checkbox_size, checkbox_size), 2)
            if file_info['selected']:
                pygame.draw.line(self.screen, checkbox_color, 
                               (checkbox_x + 3, y + 10), (checkbox_x + 7, y + 14), 2)
                pygame.draw.line(self.screen, checkbox_color, 
                               (checkbox_x + 7, y + 14), (checkbox_x + 13, y + 6), 2)
            
            # Status indicator
            status_color = Color.YELLOW if file_info['status'] == 'new' else Color.BLUE
            status_text = "NEW" if file_info['status'] == 'new' else "MOD"
            self.draw_text(status_text, 50, y + 2, self.font_small, status_color)
            
            # Filename
            filename = file_info['rel_path']
            if len(filename) > 60:
                filename = filename[:57] + "..."
            self.draw_text(filename, 100, y + 2, self.font_small, Color.WHITE)
        
        # Scrollbar
        if len(self.files_to_sync) > self.max_visible_items:
            scrollbar_height = 300
            scrollbar_y = 100
            thumb_height = max(20, scrollbar_height * self.max_visible_items // len(self.files_to_sync))
            thumb_y = scrollbar_y + (scrollbar_height - thumb_height) * self.scroll_offset // (len(self.files_to_sync) - self.max_visible_items)
            pygame.draw.rect(self.screen, Color.DARK_GRAY, (625, scrollbar_y, 5, scrollbar_height))
            pygame.draw.rect(self.screen, Color.LIGHT_GRAY, (625, thumb_y, 5, thumb_height))
    
    def draw_diff_screen(self):
        """Draw diff view screen"""
        self.screen.fill(Color.BLACK)
        
        # Header
        file_info = self.files_to_sync[self.selected_index]
        self.draw_text("File Diff", 20, 20, self.font_large, Color.WHITE)
        self.draw_text(file_info['rel_path'], 20, 55, self.font_small, Color.LIGHT_GRAY)
        
        # Instructions
        self.draw_text("UP/DOWN: Scroll  ESC: Back", 20, 85, self.font_small, Color.GRAY)
        
        # Diff content
        y_offset = 120
        line_height = 20
        max_lines = 16
        
        visible_start = self.diff_scroll
        visible_end = min(visible_start + max_lines, len(self.diff_lines))
        
        for i in range(visible_start, visible_end):
            line = self.diff_lines[i]
            y = y_offset + (i - visible_start) * line_height
            
            # Color code diff lines
            color = Color.WHITE
            if line.startswith('+'):
                color = Color.GREEN
            elif line.startswith('-'):
                color = Color.RED
            elif line.startswith('@@'):
                color = Color.YELLOW
            
            # Truncate long lines
            display_line = line[:80] if len(line) > 80 else line
            self.draw_text(display_line, 20, y, self.font_small, color)
    
    def draw_confirm_screen(self):
        """Draw confirmation screen"""
        self.screen.fill(Color.BLACK)
        
        selected_count = len([f for f in self.files_to_sync if f['selected']])
        
        self.draw_text("Confirm Sync", 320, 150, self.font_large, Color.WHITE, center=True)
        self.draw_text(f"Sync {selected_count} file(s) to root partition?", 
                      320, 220, self.font_medium, Color.LIGHT_GRAY, center=True)
        self.draw_text("This will overwrite existing files!", 
                      320, 260, self.font_small, Color.YELLOW, center=True)
        
        self.draw_text("ENTER: Confirm    ESC: Cancel", 
                      320, 350, self.font_medium, Color.GRAY, center=True)
    
    def draw_syncing_screen(self, success, fail):
        """Draw syncing progress screen"""
        self.screen.fill(Color.BLACK)
        
        self.draw_text("Syncing Files...", 320, 200, self.font_large, Color.WHITE, center=True)
        self.draw_text(f"Success: {success}  Failed: {fail}", 
                      320, 260, self.font_medium, Color.LIGHT_GRAY, center=True)
    
    def draw_done_screen(self, success, fail):
        """Draw completion screen"""
        self.screen.fill(Color.BLACK)
        
        self.draw_text("Sync Complete", 320, 150, self.font_large, Color.GREEN, center=True)
        self.draw_text(f"Successfully synced: {success}", 
                      320, 220, self.font_medium, Color.WHITE, center=True)
        if fail > 0:
            self.draw_text(f"Failed: {fail}", 
                          320, 260, self.font_medium, Color.RED, center=True)
        
        self.draw_text("Press any key to exit", 
                      320, 350, self.font_small, Color.GRAY, center=True)
    
    def handle_input(self):
        """Handle keyboard/controller input"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            
            elif event.type == pygame.KEYDOWN:
                if self.state == "scan":
                    if event.key == pygame.K_ESCAPE:
                        self.running = False
                
                elif self.state == "list":
                    if event.key == pygame.K_ESCAPE:
                        self.running = False
                    
                    elif event.key == pygame.K_UP:
                        if self.selected_index > 0:
                            self.selected_index -= 1
                            if self.selected_index < self.scroll_offset:
                                self.scroll_offset = self.selected_index
                    
                    elif event.key == pygame.K_DOWN:
                        if self.selected_index < len(self.files_to_sync) - 1:
                            self.selected_index += 1
                            if self.selected_index >= self.scroll_offset + self.max_visible_items:
                                self.scroll_offset = self.selected_index - self.max_visible_items + 1
                    
                    elif event.key == pygame.K_SPACE:
                        self.files_to_sync[self.selected_index]['selected'] = \
                            not self.files_to_sync[self.selected_index]['selected']
                    
                    elif event.key == pygame.K_d:
                        # View diff
                        file_info = self.files_to_sync[self.selected_index]
                        self.diff_lines = self.get_file_diff(file_info['src'], file_info['dest'])
                        self.diff_scroll = 0
                        self.state = "diff"
                    
                    elif event.key == pygame.K_RETURN:
                        # Go to confirm screen
                        if any(f['selected'] for f in self.files_to_sync):
                            self.state = "confirm"
                
                elif self.state == "diff":
                    if event.key == pygame.K_ESCAPE:
                        self.state = "list"
                    
                    elif event.key == pygame.K_UP:
                        if self.diff_scroll > 0:
                            self.diff_scroll -= 1
                    
                    elif event.key == pygame.K_DOWN:
                        max_scroll = max(0, len(self.diff_lines) - 16)
                        if self.diff_scroll < max_scroll:
                            self.diff_scroll += 1
                
                elif self.state == "confirm":
                    if event.key == pygame.K_ESCAPE:
                        self.state = "list"
                    
                    elif event.key == pygame.K_RETURN:
                        # Start syncing
                        self.state = "syncing"
                
                elif self.state == "done":
                    self.running = False
    
    def run(self):
        """Main application loop"""
        # Initial scan
        if not self.check_system_folder():
            # No System folder found
            while self.running:
                self.handle_input()
                self.draw_scan_screen()
                pygame.display.flip()
                self.clock.tick(30)
            pygame.quit()
            return
        
        if not self.files_to_sync:
            # All files are identical
            self.state = "done"
            success = 0
            fail = 0
        else:
            self.state = "list"
        
        success = 0
        fail = 0
        
        # Main loop
        while self.running:
            self.handle_input()
            
            if self.state == "scan":
                self.draw_scan_screen()
            
            elif self.state == "list":
                self.draw_list_screen()
            
            elif self.state == "diff":
                self.draw_diff_screen()
            
            elif self.state == "confirm":
                self.draw_confirm_screen()
            
            elif self.state == "syncing":
                self.draw_syncing_screen(success, fail)
                pygame.display.flip()
                # Perform sync
                success, fail = self.sync_selected_files()
                self.state = "done"
            
            elif self.state == "done":
                self.draw_done_screen(success, fail)
            
            pygame.display.flip()
            self.clock.tick(30)
        
        pygame.quit()


def main():
    """Main entry point"""
    # Parse command line arguments
    roms_path = "/storage/roms"
    root_path = "/"
    
    if len(sys.argv) > 1:
        roms_path = sys.argv[1]
    if len(sys.argv) > 2:
        root_path = sys.argv[2]
    
    # Create and run UI
    app = SystemSyncUI(roms_path=roms_path, root_path=root_path)
    app.run()


if __name__ == "__main__":
    main()
