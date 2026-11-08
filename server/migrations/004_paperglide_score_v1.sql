-- Immutable casual high-score board for Paper Flight (纸上飞行).
-- Reapplying after a partially failed migration never changes a matching board;
-- a conflicting definition fails instead of silently rewriting ranking rules.
INSERT INTO game_lb_boards
(namespace,id,rules_version,direction,min_score,max_score,min_duration_ms,max_duration_ms,`open`)
VALUES
('production','paper-flight-score-v1','v1','desc',0,1000000,0,1800000,TRUE)
ON DUPLICATE KEY UPDATE
 id=IF(
  rules_version=VALUES(rules_version)
  AND direction=VALUES(direction)
  AND min_score=VALUES(min_score)
  AND max_score=VALUES(max_score)
  AND min_duration_ms=VALUES(min_duration_ms)
  AND max_duration_ms=VALUES(max_duration_ms),
  id,
  NULL
 );
