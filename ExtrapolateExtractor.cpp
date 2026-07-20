const auto& obj = context.simulationObject();

ENU pos = CoordinateHelper::toENU(obj);

double dt = context.currentSystemTime() - obj.objectTime_;

double x = pos.east
         + obj.x_vel_ * dt
         + 0.5 * obj.x_accel_ * dt * dt;

double y = pos.north
         + obj.y_vel_ * dt
         + 0.5 * obj.y_accel_ * dt * dt;

double z = pos.up
         + obj.z_vel_ * dt
         + 0.5 * obj.z_accel_ * dt * dt;

return FeatureValue({x, y, z});

ECEF pos = CoordinateHelper::toECEF(
    obj,
    context.referenceLLA());

double x = pos.x
         + ...;

double y = pos.y
         + ...;

double z = pos.z
         + ...;

return FeatureValue({x, y, z});
