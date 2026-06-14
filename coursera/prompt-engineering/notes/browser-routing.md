# Browser Routing for Quiz Screenshots

## Problem

Moodle blocks direct access to answer images via `pluginfile.php` (returns error pages). Answer images are embedded in quiz pages but can't be downloaded programmatically with just the session cookie.

## Best Approach: macOS Chrome Control + Screencapture

### Prerequisites
- Chrome must be open and logged into Saylor
- macOS screencapture permissions enabled

### Workflow

```bash
# 1. Navigate Chrome to quiz page
osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "https://learn.saylor.org/mod/quiz/attempt.php?attempt=3906280&cmid=101294&page=5"'

# 2. Resize window for full content visibility
osascript -e 'tell application "Google Chrome" to set bounds of front window to {0, 40, 1920, 1480}'

# 3. Wait for page load
sleep 3

# 4. Get Chrome window bounds
BOUNDS=$(osascript -e 'tell application "Google Chrome" to get bounds of front window')
# Returns: x1, y1, x2, y2

# 5. Capture full screen
screencapture /tmp/screen.png

# 6. Crop Chrome window from screenshot
python3 << 'PYEOF'
import numpy as np
from PIL import Image

# Parse bounds
x1, y1, x2, y2 = map(int, bounds.split(', '))

# Load and crop
img = np.array(Image.open('/tmp/screen.png'))
chrome = img[y1:y2, x1:x2]
Image.fromarray(chrome).save('/tmp/chrome_crop.png')
PYEOF
```

### Image Extraction

After cropping, use numpy to find colored pixel regions:

```python
# Find graph images by looking for saturated colors
blue = (chrome[:,:,2] > 130) & (chrome[:,:,0] < 100) & (chrome[:,:,1] < 100)
red = (chrome[:,:,0] > 130) & (chrome[:,:,1] < 80) & (chrome[:,:,2] < 80)

# Find bounding boxes of colored regions
ys, xs = np.where(blue)
if len(ys) > 0:
    print(f'Blue region: y=[{ys.min()},{ys.max()}], x=[{xs.min()},{xs.max()}]')
```

### Why Other Approaches Failed

| Method | Issue |
|--------|-------|
| Direct HTTP with cookie | Moodle returns error pages for answer images |
| Headless Chrome with profile | Cookies encrypted, can't decrypt |
| Hyperbrowser cloud browser | No session cookie, redirects to login |
| BROWSER_TOOL_CREATE_TASK | Same as Hyperbrowser, no session |

### Composio Browser Tools

The following Composio tools are available but require authentication:

- `HYPERBROWSER_START_BROWSER_USE_TASK` - Cloud browser, needs login
- `BROWSER_TOOL_CREATE_TASK` - Cloud browser, needs login
- `SCREENSHOTONE_TAKE_SCREENSHOT` - URL screenshot, needs public URL

None work for authenticated Moodle pages without injecting the session cookie.

### Alternative: Vision LLM Analysis

If screenshots are captured, use `composio run` with `experimental_subAgent()` to analyze images:

```javascript
const result = await experimental_subAgent(
  "Describe the 4 graph images labeled a, b, c, d. For each, describe the curve shape, x-intercepts, peaks, and behavior at edges.",
  { schema: z.object({ descriptions: z.array(z.string()) }) }
);
```

This requires passing image data to the LLM, which isn't directly supported in the current setup.

## Session Cookie

Current valid cookie: `MoodleSessionsaylor=53ef2a849dc9436ca4455b6fe2742081`

Expires when session ends or after 7 days of inactivity.

## Quiz Page URLs

- MA122: `https://learn.saylor.org/mod/quiz/attempt.php?attempt=3906280&cmid=101294&page={0-8}`
- MA121: `https://learn.saylor.org/mod/quiz/attempt.php?attempt=3906176&cmid=101292&page={0-8}`

Each page has 5 questions (except page 8 which has 6).
