using System.Windows.Media;

namespace NAPS2.EtoForms.Wpf;

/// <summary>
/// Glyphs from the Windows icon font: Segoe Fluent Icons on Windows 11, falling back to Segoe MDL2 Assets on Windows 10
/// (which has mostly the same glyphs at the same code points).
/// </summary>
internal static class FluentIcons
{
    public static FontFamily FontFamily { get; } = new("Segoe Fluent Icons, Segoe MDL2 Assets");

    public const string Add = "";
    public const string Back = "";
    public const string BackToWindow = "";
    public const string Brightness = "";
    public const string CheckMark = "";
    public const string ChevronDown = "";
    public const string Color = "";
    public const string Contrast = "";
    public const string Copy = "";
    public const string Crop = "";
    public const string Cut = "";
    public const string Delete = "";
    public const string DockLeft = "";
    public const string Document = "";
    public const string Down = "";
    public const string Edit = "";
    public const string EraseTool = "";
    public const string Filter = "";
    public const string FitPage = "";
    public const string Font = "";
    public const string Forward = "";
    public const string FullScreen = "";
    public const string Globe = "";
    public const string Import = "";
    public const string Info = "";
    public const string Library = "";
    public const string Link = "";
    public const string Mail = "";
    public const string Network = "";
    public const string Paste = "";
    public const string Pdf = "";
    public const string Permissions = "";
    public const string Photo = "";
    public const string Print = "";
    public const string Redo = "";
    public const string Refresh = "";
    public const string Rotate = "";
    public const string Save = "";
    public const string Scan = "";
    public const string Search = "";
    public const string Settings = "";
    public const string Sort = "";
    public const string Switch = "";
    public const string TwoPage = "";
    public const string Undo = "";
    public const string Up = "";
    public const string Warning = "";
    public const string Wifi = "";
    public const string ZoomIn = "";
    public const string ZoomOut = "";

    // Icons that aren't listed here (e.g. the scanner device images) keep their default bitmaps
    private static readonly Dictionary<string, string> GlyphsByIconName = new()
    {
        { "accept", CheckMark },
        { "add", Add },
        { "application_cascade", Copy },
        { "application_side_list", DockLeft },
        { "arrow_down", Down },
        { "arrow_left", Back },
        { "arrow_out", FullScreen },
        { "arrow_refresh", Sort },
        { "arrow_right", Forward },
        { "arrow_rotate_anticlockwise", Rotate },
        { "arrow_rotate_clockwise", Refresh },
        { "arrow_switch", Switch },
        { "arrow_up", Up },
        { "blueprints", Library },
        { "broom", EraseTool },
        { "cog", Settings },
        { "color_gradient", Color },
        { "color_management", Color },
        { "color_wheel", Color },
        { "column_double", TwoPage },
        { "combine", Link },
        { "contrast", Contrast },
        { "contrast_high", Contrast },
        { "contrast_with_sun", Brightness },
        { "control_play_blue", Scan },
        { "copy", Copy },
        { "cross", Delete },
        { "diskette", Save },
        { "document", Document },
        { "email", Mail },
        { "email_attach", Mail },
        { "exclamation", Warning },
        { "file_extension_pdf", Pdf },
        { "folder_picture", Import },
        { "information", Info },
        { "key", Permissions },
        { "network_ip", Network },
        { "paste", Paste },
        { "pencil", Edit },
        { "picture_edit", Edit },
        { "pictures", Photo },
        { "printer", Print },
        { "redo", Redo },
        { "sharpen", Filter },
        { "split", Cut },
        { "spring", BackToWindow },
        { "text", Font },
        { "transform_crop", Crop },
        { "undo", Undo },
        { "weather_sun", Brightness },
        { "wireless", Wifi },
        { "world", Globe },
        { "zoom", Search },
        { "zoom_actual", FitPage },
        { "zoom_in", ZoomIn },
        { "zoom_out", ZoomOut }
    };

    /// <summary>
    /// Gets the glyph for one of NAPS2's named icons, or null if it should keep using its bitmap.
    /// </summary>
    public static string? ForIconName(string? iconName) =>
        iconName != null && GlyphsByIconName.TryGetValue(iconName, out var glyph) ? glyph : null;
}
