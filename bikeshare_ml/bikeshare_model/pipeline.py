import sys
from pathlib import Path
file = Path(__file__).resolve()
parent, root = file.parent, file.parents[1]
sys.path.append(str(root))

from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestRegressor

from bikeshare_model.config.core import config
from bikeshare_model.processing.features import WeekdayImputer, WeathersitImputer
from bikeshare_model.processing.features import Mapper
from bikeshare_model.processing.features import OutlierHandler, WeekdayOneHotEncoder

bikeshare_pipe = Pipeline([

    ######### Imputation ###########
    ('weekday_imputation', WeekdayImputer(variable = config.model_config_.weekday_var, 
                                          date_var= config.model_config_.date_var)),
    ('weathersit_imputation', WeathersitImputer(variable = config.model_config_.weathersit_var)),
    
    ######### Mapper ###########
    ('map_yr', Mapper(variable = config.model_config_.yr_var, mappings = config.model_config_.yr_mappings)),
    
    ('map_mnth', Mapper(variable = config.model_config_.mnth_var, mappings = config.model_config_.mnth_mappings)),
    
    ('map_season', Mapper(variable = config.model_config_.season_var, mappings = config.model_config_.season_mappings)),
    
    ('map_weathersit', Mapper(variable = config.model_config_.weathersit_var, mappings = config.model_config_.weathersit_mappings)),
    
    ('map_holiday', Mapper(variable = config.model_config_.holiday_var, mappings = config.model_config_.holiday_mappings)),
    
    ('map_workingday', Mapper(variable = config.model_config_.workingday_var, mappings = config.model_config_.workingday_mappings)),
    
    ('map_hr', Mapper(variable = config.model_config_.hr_var, mappings = config.model_config_.hr_mappings)),
    
    ######## Handle outliers ########
    ('handle_outliers_temp', OutlierHandler(variable = config.model_config_.temp_var)),
    ('handle_outliers_atemp', OutlierHandler(variable = config.model_config_.atemp_var)),
    ('handle_outliers_hum', OutlierHandler(variable = config.model_config_.hum_var)),
    ('handle_outliers_windspeed', OutlierHandler(variable = config.model_config_.windspeed_var)),

    ######## One-hot encoding ########
    ('encode_weekday', WeekdayOneHotEncoder(variable = config.model_config_.weekday_var)),

    # Scale features
    ('scaler', StandardScaler()),
    
    # Regressor
    ('model_rf', RandomForestRegressor(n_estimators = config.model_config_.n_estimators, 
                                       max_depth = config.model_config_.max_depth,
                                      random_state = config.model_config_.random_state))
    
    ])
