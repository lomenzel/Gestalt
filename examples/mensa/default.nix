{ target, config, ... }:
let
  baseUrl = "https://speiseplan.mcloud.digital/v2";
  defaultCity = "Kiel";

  # --- Helpers ---
  getAttrOr =
    attr: default: state:
    state.${attr} or default;

  inherit (builtins)
    elem
    concatStringsSep
    hasAttr
    filter
    elemAt
    genList
    foldl'
    ;

  getView = getAttrOr "currentView" "meals";
  getCity = getAttrOr "city" defaultCity;
  getDate = getAttrOr "date" "";
  getVegan = getAttrOr "vegan" false;
  getVegetarian = getAttrOr "vegetarian" false;
  getLocations = getAttrOr "availableLocations" [ ];
  getSelectedLocations = getAttrOr "selectedLocations" [ ];
  getAllergens = getAttrOr "availableAllergens" [ ];
  getExcludedAllergens = getAttrOr "excludedAllergens" [ ];
  getMenu = getAttrOr "menu" [ ];
  getLanguage = getAttrOr "language" "";
  getAvailableDates = getAttrOr "availableDates" [ ];

  isLocSelected = state: loc: elem loc.code (getSelectedLocations state);

  isAllergenExcluded = state: a: elem a.code (getExcludedAllergens state);

  joinComma = concatStringsSep ",";

  buildMealsUrl =
    state:
    baseUrl
    + "/meals"
    + "?location="
    + (joinComma (getSelectedLocations state))
    + (if (getVegan state) then "&vegan=true" else "")
    + (if (getVegetarian state) then "&vegetarian=true" else "")
    + (if (getDate state) != "" then "&date=" + (getDate state) else "")
    + (
      if (builtins.trace "Excluded allergens" (getExcludedAllergens state)) != [ ] then
        "&excludeAllergens=" + (joinComma (getExcludedAllergens state))
      else
        ""
    )
    + (if (getLanguage state) != "" then "&language=" + (getLanguage state) else "");

  mealEmoji =
    meal:
    if meal.vegan then
      "🌱 "
    else if meal.vegetarian then
      "🧀 "
    else
      "🍖 ";

  formatPrice =
    meal:
    (toString meal.price.students)
    + "€"
    + " / "
    + (toString meal.price.employees)
    + "€"
    + " / "
    + (toString meal.price.guests)
    + "€";

  formatAllergens =
    meal:
    if hasAttr "allergens" meal && meal.allergens != [ ] then
      " [" + (concatStringsSep ", " (map (a: a.name) meal.allergens)) + "]"
    else
      "";

  getCurrentDateIndex =
    state:
    if
      (filter (i: elemAt (getAvailableDates state) i == (getDate state)) (
        genList (i: i) (builtins.length (getAvailableDates state))
      )) == [ ]
    then
      0
    else
      builtins.head (
        filter (i: elemAt (getAvailableDates state) i == (getDate state)) (
          genList (i: i) (builtins.length (getAvailableDates state))
        )
      );

  uniqueDates =
    meals: foldl' (acc: d: if elem d acc then acc else acc ++ [ d ]) [ ] (map (m: m.date) meals);

  mealsForDate =
    state:
    if (getDate state) == "" then
      (getMenu state)
    else
      filter (m: m.date == (getDate state)) (getMenu state);

  locationsUrl =
    state: baseUrl + "/locations" + (if (getCity state) != "" then "?city=" + (getCity state) else "");

  allergensUrl = state: baseUrl + "/allergens";
  # --- View helpers split by page ---

  mealsActions =
    state:
    (
      if (getCurrentDateIndex state) > 0 then
        [
          {
            content = "← Previous Day";
            actionId = "prevDay";
            annotations = [ ];
          }
        ]
      else
        [ ]
    )
    ++ (
      if (getCurrentDateIndex state) < (builtins.length (getAvailableDates state) - 1) then
        [
          {
            content = "Next Day →";
            actionId = "nextDay";
            annotations = [ ];
          }
        ]
      else
        [ ]
    )
    ++ [
      {
        content = "Refresh Menu";
        actionId = "refresh";
        annotations = [ ];
      }
      {
        content = "Settings";
        actionId = "navToSettings";
        annotations = [ target.capabilities.annotations.actions.navigation ];
      }
    ];

  settingsActions =
    state:
    [
      {
        content = "Back to Menu";
        actionId = "navToMeals";
        annotations = [ target.capabilities.annotations.actions.navigation ];
      }
    ]
    ++ (
      if getVegan state then
        [
          {
            content = "Disable Vegan Filter";
            actionId = "setVegan";
            params = {
              value = false;
            };
            annotations = [ ];
          }
        ]
      else
        [
          {
            content = "Enable Vegan Filter";
            actionId = "setVegan";
            params = {
              value = true;
            };
            annotations = [ ];
          }
        ]
    )
    ++ (
      if getVegetarian state then
        [
          {
            content = "Disable Vegetarian Filter";
            actionId = "setVegetarian";
            params = {
              value = false;
            };
            annotations = [ ];
          }
        ]
      else
        [
          {
            content = "Enable Vegetarian Filter";
            actionId = "setVegetarian";
            params = {
              value = true;
            };
            annotations = [ ];
          }
        ]
    )
    ++ [
      {
        content = "Set Date";
        actionId = "setDate";
        annotations = [ ];
      }
      {
        content = "Set City";
        actionId = "setCity";
        annotations = [ ];
      }
      {
        content = "Select Locations";
        actionId = "navToLocations";
        annotations = [ target.capabilities.annotations.actions.navigation ];
      }
      {
        content = "Filter Allergens";
        actionId = "navToAllergens";
        annotations = [ target.capabilities.annotations.actions.navigation ];
      }
    ];

  locationsActions =
    state:
    [
      {
        content = "Back to Settings";
        actionId = "navToSettings";
        annotations = [ target.capabilities.annotations.actions.navigation ];
      }
      {
        content = "Refresh Locations";
        actionId = "fetchLocations";
        annotations = [ ];
      }
      {
        content = "Clear All Locations";
        actionId = "clearLocations";
        annotations = [ ];
      }
    ]
    ++ (map (
      loc:
      if isLocSelected state loc then
        {
          content = "Deselect: " + loc.name + " (" + loc.code + ")";
          actionId = "deselectLocation";
          params = {
            code = loc.code;
          };
          annotations = [ ];
        }
      else
        {
          content = "Select: " + loc.name + " (" + loc.code + ")";
          actionId = "selectLocation";
          params = {
            code = loc.code;
          };
          annotations = [ ];
        }
    ) (getLocations state));

  allergensActions =
    state:
    [
      {
        content = "Back to Settings";
        actionId = "navToSettings";
        annotations = [ target.capabilities.annotations.actions.navigation ];
      }
      {
        content = "Refresh Allergens";
        actionId = "fetchAllergens";
        annotations = [ ];
      }
      {
        content = "Clear All Allergen Filters";
        actionId = "clearAllergens";
        annotations = [ ];
      }
    ]
    ++ (map (
      a:
      if isAllergenExcluded state a then
        {
          content = "Include: " + a.name + " (" + a.code + ")";
          actionId = "includeAllergen";
          params = {
            code = a.code;
          };
          annotations = [ ];
        }
      else
        {
          content = "Exclude: " + a.name + " (" + a.code + ")";
          actionId = "excludeAllergen";
          params = {
            code = a.code;
          };
          annotations = [ ];
        }
    ) (getAllergens state));

  mealsElements =
    state:
    [
      {
        content =
          "📅 "
          + (if (getDate state) == "" then "All Days" else (getDate state))
          + " | 📍 "
          + (getCity state)
          + " ("
          + (if (getSelectedLocations state) != [ ] then joinComma (getSelectedLocations state) else "all")
          + ")"
          + (if (getVegan state) then " | Vegan" else "")
          + (if (getVegetarian state) then " | Vegetarian" else "");
        annotations = [ target.capabilities.annotations.ui.important ];
      }
    ]
    ++ (
      if (getAvailableDates state) != [ ] then
        [
          {
            content = "Days: " + (concatStringsSep " · " (getAvailableDates state));
            annotations = [ ];
          }
        ]
      else
        [ ]
    )
    ++ (
      if (mealsForDate state) != [ ] then
        map (meal: {
          content =
            (mealEmoji meal)
            + meal.name
            + "\n"
            + "📍 "
            + meal.location.name
            + " | "
            + (formatPrice meal)
            + (formatAllergens meal);
          annotations = [ ];
        }) (mealsForDate state)
      else
        [
          {
            content = "No meals loaded. Hit Refresh.";
            annotations = [ ];
          }
        ]
    );

  settingsElements = state: [
    {
      content = "⚙️ Settings";
      annotations = [ target.capabilities.annotations.ui.important ];
    }
    {
      content = "City: " + (getCity state);
      annotations = [ ];
    }
    {
      content = "Date: " + (if (getDate state) == "" then "All / Today" else (getDate state));
      annotations = [ ];
    }
    {
      content = "Vegan: " + (if (getVegan state) then "✅" else "❌");
      annotations = [ ];
    }
    {
      content = "Vegetarian: " + (if (getVegetarian state) then "✅" else "❌");
      annotations = [ ];
    }
    {
      content =
        "Selected Locations: "
        + (if (getSelectedLocations state) == [ ] then "all" else joinComma (getSelectedLocations state));
      annotations = [ ];
    }
    {
      content =
        "Excluded Allergens: "
        + (if (getExcludedAllergens state) == [ ] then "none" else joinComma (getExcludedAllergens state));
      annotations = [ ];
    }
  ];

  locationsElements =
    state:
    [
      {
        content =
          "📍 Location Selection (" + (toString (builtins.length (getSelectedLocations state))) + " selected)";
        annotations = [ target.capabilities.annotations.ui.important ];
      }
    ]
    ++ (
      if (getLocations state) == [ ] then
        [
          {
            content = "No locations loaded. Hit Refresh.";
            annotations = [ ];
          }
        ]
      else
        map (loc: {
          content =
            (if isLocSelected state loc then "✅ " else "⬜ ") + loc.name + " (" + loc.code + ") — " + loc.city;
          annotations = [ ];
        }) (getLocations state)
    );

  allergensElements =
    state:
    [
      {
        content =
          "⚠️ Allergen Filters (" + (toString (builtins.length (getExcludedAllergens state))) + " excluded)";
        annotations = [ target.capabilities.annotations.ui.important ];
      }
    ]
    ++ (
      if (getAllergens state) == [ ] then
        [
          {
            content = "No allergens loaded. Hit Refresh.";
            annotations = [ ];
          }
        ]
      else
        (map (a: {
          content = (if isAllergenExcluded state a then "🚫 " else "✅ ") + a.name + " (" + a.code + ")";
          annotations = [ ];
        }) (getAllergens state))
    );

in
{
  # ================================================================
  # VIEW
  # ================================================================
  view = [
    (state: {
      actions = (
        if (getView state) == "meals" then
          mealsActions state
        else if (getView state) == "settings" then
          settingsActions state
        else if (getView state) == "locations" then
          locationsActions state
        else if (getView state) == "allergens" then
          allergensActions state
        else
          [ ]
      );

      elements = (
        if (getView state) == "meals" then
          mealsElements state
        else if (getView state) == "settings" then
          settingsElements state
        else if (getView state) == "locations" then
          locationsElements state
        else if (getView state) == "allergens" then
          allergensElements state
        else
          [ ]
      );
    })
  ];

  # ================================================================
  # ACTIONS
  # ================================================================
  actions = {

    # --- Navigation ---
    navToSettings = {
      function =
        { state }:
        {
          state = state // {
            currentView = "settings";
          };
          effect = target.capabilities.effects.noop;
        };
    };

    navToMeals = {
      function =
        { state }:
        {
          state = state // {
            currentView = "meals";
          };
          effect = target.capabilities.effects.noop;
        };
    };

    navToLocations = {
      function =
        { state }:
        {
          state = state // {
            currentView = "locations";
          };
          effect =
            if (getLocations state) == [ ] then
              target.capabilities.effects.httpRequest {
                method = "GET";
                url = locationsUrl state;
                callBackActionId = "handleLocationsResult";
              }
            else
              target.capabilities.effects.noop;
        };
    };

    navToAllergens = {
      function =
        { state }:
        {
          state = state // {
            currentView = "allergens";
          };
          effect =
            if (getAllergens state) == [ ] then
              target.capabilities.effects.httpRequest {
                method = "GET";
                url = allergensUrl state;
                callBackActionId = "handleAllergensResult";
              }
            else
              target.capabilities.effects.noop;
        };
    };

    # --- Settings Modifications ---
    setVegan = {
      function =
        { state, params }:
        {
          state = state // {
            vegan = params.value;
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          value = {
            _type = "boolean";
            description = "Enable Vegan Filter";
          };
        };
      };
    };

    setVegetarian = {
      function =
        { state, params }:
        {
          state = state // {
            vegetarian = params.value;
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          value = {
            _type = "boolean";
            description = "Enable Vegetarian Filter";
          };
        };
      };
    };

    setCity = {
      function =
        { state, params }:
        {
          state = state // {
            city = params.city;
            availableLocations = [ ];
            selectedLocations = [ ];
            availableAllergens = [ ];
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          city = {
            _type = "string";
            description = "City name (e.g. Kiel, Luebeck)";
          };
        };
      };
    };

    setDate = {
      function =
        { state, params }:
        {
          state = state // {
            date = params.dateStr;
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          dateStr = {
            _type = "string";
            description = "YYYY-MM-DD or empty for all days";
          };
        };
      };
    };

    # --- Day Navigation ---
    prevDay = {
      function =
        { state }:
        {
          state = state // {
            date = elemAt (getAvailableDates state) (
              if (getCurrentDateIndex state) > 0 then (getCurrentDateIndex state) - 1 else 0
            );
          };
          effect = target.capabilities.effects.noop;
        };
    };

    nextDay = {
      function =
        { state }:
        {
          state = state // {
            date = elemAt (getAvailableDates state) (
              if (getCurrentDateIndex state) < (builtins.length (getAvailableDates state) - 1) then
                (getCurrentDateIndex state) + 1
              else
                (getCurrentDateIndex state)
            );
          };
          effect = target.capabilities.effects.noop;
        };
    };

    # --- Location Selection ---
    selectLocation = {
      function =
        { state, params }:
        {
          state = state // {
            selectedLocations = (getSelectedLocations state) ++ [ params.code ];
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          code = {
            _type = "string";
            description = "Location code";
          };
        };
      };
    };

    deselectLocation = {
      function =
        { state, params }:
        {
          state = state // {
            selectedLocations = filter (c: c != params.code) (getSelectedLocations state);
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          code = {
            _type = "string";
            description = "Location code";
          };
        };
      };
    };

    clearLocations = {
      function =
        { state }:
        {
          state = state // {
            selectedLocations = [ ];
          };
          effect = target.capabilities.effects.noop;
        };
    };

    # --- Allergen Selection ---
    excludeAllergen = {
      function =
        { state, params }:
        {
          state = state // {
            excludedAllergens = (getExcludedAllergens state) ++ [ params.code ];
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          code = {
            _type = "string";
            description = "Allergen code";
          };
        };
      };
    };

    includeAllergen = {
      function =
        { state, params }:
        {
          state = state // {
            excludedAllergens = filter (c: c != params.code) (getExcludedAllergens state);
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          code = {
            _type = "string";
            description = "Allergen code";
          };
        };
      };
    };

    clearAllergens = {
      function =
        { state }:
        {
          state = state // {
            excludedAllergens = [ ];
          };
          effect = target.capabilities.effects.noop;
        };
    };

    # --- Data Fetching ---
    fetchLocations = {
      function =
        { state }:
        {
          state = state;
          effect = target.capabilities.effects.httpRequest {
            method = "GET";
            url = locationsUrl state;
            callBackActionId = "handleLocationsResult";
          };
        };
    };

    handleLocationsResult = {
      function =
        { state, params }:
        {
          state = state // {
            availableLocations = (builtins.fromJSON params.body).data;
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = { };
      };
    };

    fetchAllergens = {
      function =
        { state }:
        {
          state = state;
          effect = target.capabilities.effects.httpRequest {
            method = "GET";
            url = allergensUrl state;
            callBackActionId = "handleAllergensResult";
          };
        };
    };

    handleAllergensResult = {
      function =
        { state, params }:
        {
          state = state // {
            availableAllergens = (builtins.fromJSON params.body).data;
          };
          effect = target.capabilities.effects.log {
            message = builtins.toJSON (getExcludedAllergens state);
          };
        };
      paramType = {
        _type = "struct";
        fields = { };
      };
    };

    refresh = {
      function =
        { state }:
        {
          state = state;
          effect = target.capabilities.effects.httpRequest {
            method = "GET";
            url = builtins.trace "Fetching meals URL" (buildMealsUrl state);
            callBackActionId = "handleMealsResult";
          };
        };
    };

    handleMealsResult = {
      function =
        { state, params }:
        {
          state = state // {
            menu = (builtins.fromJSON params.body).data;
            availableDates = uniqueDates (builtins.fromJSON params.body).data;
            date =
              if (getDate state) == "" && (uniqueDates (builtins.fromJSON params.body).data) != [ ] then
                builtins.head (uniqueDates (builtins.fromJSON params.body).data)
              else
                (getDate state);
          };
          effect = target.capabilities.effects.log {
            message =
              "Menu loaded: "
              + (toString (builtins.length (builtins.fromJSON params.body).data))
              + " meals across "
              + (toString (builtins.length (uniqueDates (builtins.fromJSON params.body).data)))
              + " days.";
          };
        };
      paramType = {
        _type = "struct";
        fields = { };
      };
    };
  };
  title = "Mensa SH";
  name = "mensa-sh";
  version = "0.1.0";
  author.name = "Leonard Menzel";
}
