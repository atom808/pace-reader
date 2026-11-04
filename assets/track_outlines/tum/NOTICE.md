# TUM racetrack database: three circuits

`Sakhir.csv`, `Catalunya.csv` and `Monza.csv` are copied unchanged from the
TUM racetrack database, commit `e59595d1f3573b30d1ded6a08984935b957688e0`
(2021-09-18): <https://github.com/TUMFTM/racetrack-database>, folder `tracks/`.

Each row is `x_m, y_m, w_tr_right_m, w_tr_left_m`: a point of the smoothed
centreline and the track's width to its right and left. TUM made the
centrelines from OpenStreetMap GPS points and measured the widths on
satellite images.

The data are licensed under the GNU Lesser General Public License v3.0, in
`LICENSE` beside this file. Pace Reader reads the files as they are and
fits them to a recording's lap at run time
(`lib/features/track_outline/domain/public_outline.dart`). To use other
versions, replace the files.
