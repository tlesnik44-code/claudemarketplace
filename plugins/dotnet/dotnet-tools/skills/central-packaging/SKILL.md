---
name: central-packaging
description: Enable NuGet Central Package Management for .NET projects. Use when setting up central packaging, adding Directory.Build.props, Directory.Packages.props, nuget.config, or migrating existing projects to central versioning.
---

# Enable Central Package Management

Enable NuGet Central Package Management (CPM) for a .NET project.

## Steps

1. **Create/update nuget.config** in solution root
2. **Create/update Directory.Build.props** in solution root
3. **Create/update Directory.Packages.props** in solution root
4. **Update .csproj files** - remove version attributes from PackageReference
5. **Suppress warnings** in Directory.Build.props if needed
6. **Build and verify** - ensure no version conflicts

## File Templates

### nuget.config
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <disabledPackageSources />
</configuration>
```

If using a private NuGet feed, add it as an additional package source and configure `packageSourceMapping` to route internal packages to it.

### Directory.Build.props
```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <!-- Warning suppressions (add as needed) -->
  <PropertyGroup>
    <NoWarn>$(NoWarn);NU1902;NU1903;NU1904</NoWarn>
  </PropertyGroup>
</Project>
```

**Common warnings to suppress:**
- `NU1902` - Package has known moderate vulnerability
- `NU1903` - Package has known high vulnerability
- `NU1904` - Package has known critical vulnerability
- `CS1591` - Missing XML comment for publicly visible type
- `SYSLIB0051` - Legacy serialization is obsolete

### Directory.Packages.props
```xml
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <!-- Add PackageVersion entries for all packages used -->
    <PackageVersion Include="PackageName" Version="x.y.z" />
  </ItemGroup>
</Project>
```

## Migration Process

### When migrating existing project:

1. **Extract all package references**:
   ```bash
   grep -rh "PackageReference" --include="*.csproj" | sort -u
   ```

2. **Create Directory.Packages.props** with all unique packages and versions

3. **Update .csproj files** - remove `Version` attribute:
   ```xml
   <!-- Before -->
   <PackageReference Include="Newtonsoft.Json" Version="13.0.4" />

   <!-- After -->
   <PackageReference Include="Newtonsoft.Json" />
   ```

4. **Handle version conflicts** - if same package has different versions:
   - Pick one version in Directory.Packages.props
   - Or use `VersionOverride` in specific .csproj if truly needed

## Important Considerations

### Floating versions not allowed
CPM does not support floating versions like `4.4.*`. Use exact versions.

### Version unification may break tests
When unifying package versions, API changes between versions can cause build errors:
- **FluentAssertions**: `Throw` -> `ThrowAsync` (v5 -> v6)
- **xunit.runner.visualstudio**: Major version changes between 2.x and 3.x
- Keep original versions if tests break, or fix the test code

### Mixed target frameworks
If project has mixed frameworks (netstandard2.0, net8.0), do NOT set TargetFramework in Directory.Build.props - let each csproj define its own.

## Verification

After setup:
```bash
dotnet restore
dotnet build
```

If build fails with version errors:
- Check all PackageReference entries have matching PackageVersion
- Ensure no duplicate PackageVersion entries
- Verify transitive dependencies are compatible
- For breaking API changes, fix code or use original version